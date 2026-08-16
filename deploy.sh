#!/usr/bin/env bash
# Reconcile a Jekyll build to the corporate R2 bucket. Usage: ./deploy.sh [--force-full] [--dry-run]
set -u

S3_BUCKET="cyberknight-corporate-site-production"
SITE_DIR="${SITE_DIR:-_site}"
MANIFEST_KEY=".manifest.json"
CF_ZONE_ID="9dbd179caf99bb5fd469db1545fbb431"
LOCK_DIR="${DEPLOY_LOCK_DIR:-${TMPDIR:-/tmp}/cyberknight-corporate-site-production.deploy.lock}"
DOPPLER_PROJECT="cyberknight-s3-sync"
DOPPLER_CONFIG="prd"

FORCE_FULL=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --force-full) FORCE_FULL=true ;;
    --dry-run) DRY_RUN=true ;;
    *) echo "ERROR: Unknown argument '$arg'. Usage: $0 [--force-full] [--dry-run]" >&2; exit 1 ;;
  esac
done

for command in aws doppler jq curl; do
  command -v "$command" >/dev/null 2>&1 || { echo "ERROR: $command is required." >&2; exit 1; }
done
if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  echo "ERROR: sha256sum or shasum is required." >&2
  exit 1
fi
[ -d "$SITE_DIR" ] || { echo "ERROR: Site directory '$SITE_DIR' not found." >&2; exit 1; }

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "ERROR: Deployment lock already exists at $LOCK_DIR; refusing concurrent deployment." >&2
  exit 1
fi
LOCK_OWNER="$$-$(date +%s)"
printf '%s\n' "$LOCK_OWNER" > "$LOCK_DIR/owner"
TMP_DIR=""
cleanup() {
  status=$?
  [ -z "$TMP_DIR" ] || rm -rf "$TMP_DIR"
  if [ -f "$LOCK_DIR/owner" ] && [ "$(cat "$LOCK_DIR/owner" 2>/dev/null || true)" = "$LOCK_OWNER" ]; then
    rm -rf "$LOCK_DIR"
  fi
  trap - EXIT INT TERM
  exit "$status"
}
trap cleanup EXIT INT TERM

DOPPLER_AUTH_TOKEN="${DOPPLER_TOKEN:-}"
if [ -z "$DOPPLER_AUTH_TOKEN" ] && command -v pass >/dev/null 2>&1; then
  DOPPLER_AUTH_TOKEN="$(pass show cyberknight/s3-sync-doppler-token 2>/dev/null)" || DOPPLER_AUTH_TOKEN=""
fi
secret() {
  if [ -n "$DOPPLER_AUTH_TOKEN" ]; then
    DOPPLER_TOKEN="$DOPPLER_AUTH_TOKEN" doppler secrets get "$1" --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain
  else
    env -u DOPPLER_TOKEN doppler secrets get "$1" --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain
  fi
}
R2_ACCOUNT_ID="$(secret R2_ACCOUNT_ID)" || { echo "ERROR: Could not retrieve R2_ACCOUNT_ID." >&2; exit 1; }
R2_ACCESS_KEY_ID="$(secret R2_ACCESS_KEY_ID)" || { echo "ERROR: Could not retrieve R2_ACCESS_KEY_ID." >&2; exit 1; }
R2_SECRET_ACCESS_KEY="$(secret R2_SECRET_ACCESS_KEY)" || { echo "ERROR: Could not retrieve R2_SECRET_ACCESS_KEY." >&2; exit 1; }
CF_TOKEN="$(secret CLOUDFLARE_API_TOKEN)" || { echo "ERROR: Could not retrieve CLOUDFLARE_API_TOKEN." >&2; exit 1; }
[ -n "$R2_ACCOUNT_ID" ] && [ -n "$R2_ACCESS_KEY_ID" ] && [ -n "$R2_SECRET_ACCESS_KEY" ] && [ -n "$CF_TOKEN" ] || {
  echo "ERROR: Required R2 credentials or Cloudflare API token are empty." >&2; exit 1;
}
R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
aws_r2() {
  env AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
    AWS_DEFAULT_REGION=auto AWS_REGION=auto aws --endpoint-url "$R2_ENDPOINT" "$@"
}

TMP_DIR="$(mktemp -d)"
CURRENT="$TMP_DIR/current.tsv"
REMOTE="$TMP_DIR/remote.tsv"
TO_UPLOAD="$TMP_DIR/upload.tsv"
TO_DELETE="$TMP_DIR/delete.txt"

mime_type() {
  case "$1" in
    *.html|*.htm) echo 'text/html; charset=utf-8' ;;
    *.json) echo 'application/json; charset=utf-8' ;;
    *.xml) echo 'application/xml; charset=utf-8' ;;
    *.txt) echo 'text/plain; charset=utf-8' ;;
    *.css) echo 'text/css; charset=utf-8' ;;
    *.js|*.mjs) echo 'application/javascript; charset=utf-8' ;;
    *.svg) echo 'image/svg+xml' ;;
    *.png) echo 'image/png' ;; *.jpg|*.jpeg) echo 'image/jpeg' ;; *.gif) echo 'image/gif' ;;
    *.webp) echo 'image/webp' ;; *.ico) echo 'image/x-icon' ;; *.woff2) echo 'font/woff2' ;;
    *.woff) echo 'font/woff' ;; *.pdf) echo 'application/pdf' ;; *) echo 'application/octet-stream' ;;
  esac
}
cache_control() {
  case "$1" in
    *.html|*.htm|*.json|*.xml|*.txt) echo 'public, max-age=300' ;;
    *[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*.*) echo 'public, max-age=31536000, immutable' ;;
    *) echo 'public, max-age=300' ;;
  esac
}

# path, size, content type, cache control, sha256. The deployment manifest is never site content.
# Validate NUL-delimited paths before converting them to the line-based inventory.
: > "$CURRENT"
while IFS= read -r -d '' file; do
  key="${file#${SITE_DIR}/}"
  [ "$key" = "$MANIFEST_KEY" ] && continue
  case "$key" in
    *$'\t'*|*$'\n'*|*$'\r'*|*[[:cntrl:]]*)
      echo "ERROR: Unsafe site filename (tab, newline, carriage return, or control character): '$key'." >&2
      exit 1
      ;;
  esac
  printf '%s\t%s\t%s\t%s\t%s\n' "$key" "$(wc -c < "$file" | tr -d ' ')" "$(mime_type "$key")" "$(cache_control "$key")" "$(sha256 "$file")" >> "$CURRENT"
done < <(find "$SITE_DIR" -type f -print0 | LC_ALL=C sort -z)
LC_ALL=C sort -o "$CURRENT" "$CURRENT"
[ -s "$CURRENT" ] || { echo "ERROR: Refusing to deploy an empty site inventory." >&2; exit 1; }
grep -q $'^index.html\t' "$CURRENT" || { echo "ERROR: Refusing to deploy without index.html." >&2; exit 1; }

fetch_remote() {
  aws_r2 s3api list-objects-v2 --bucket "$S3_BUCKET" --output json > "$TMP_DIR/remote.json" || {
    echo "ERROR: Could not list remote R2 inventory." >&2; exit 1;
  }
  jq -r --arg manifest "$MANIFEST_KEY" '.Contents[]? | select(.Key != $manifest) | [.Key, (.Size | tostring)] | @tsv' "$TMP_DIR/remote.json" | LC_ALL=C sort > "$REMOTE"
}
fetch_remote

: > "$TO_UPLOAD"
while IFS=$'\t' read -r key size type cache hash; do
  changed=$FORCE_FULL
  remote_size="$(awk -F '\t' -v key="$key" '$1 == key { print $2; exit }' "$REMOTE")"
  if [ "$changed" = false ] && [ "$remote_size" = "$size" ]; then
    head="$TMP_DIR/head.json"
    if aws_r2 s3api head-object --bucket "$S3_BUCKET" --key "$key" --output json > "$head" 2>/dev/null \
      && [ "$(jq -r '.ContentLength' "$head")" = "$size" ] \
      && [ "$(jq -r '.ContentType // ""' "$head")" = "$type" ] \
      && [ "$(jq -r '.CacheControl // ""' "$head")" = "$cache" ] \
      && [ "$(jq -r '.Metadata.sha256 // ""' "$head")" = "$hash" ]; then
      changed=false
    else
      changed=true
    fi
  else
    changed=true
  fi
  [ "$changed" = true ] && printf '%s\t%s\t%s\t%s\t%s\n' "$key" "$size" "$type" "$cache" "$hash" >> "$TO_UPLOAD"
done < "$CURRENT"

: > "$TO_DELETE"
while IFS=$'\t' read -r key _; do
  grep -Fqx "$key" <(cut -f1 "$CURRENT") || printf '%s\n' "$key" >> "$TO_DELETE"
done < "$REMOTE"

upload_count="$(wc -l < "$TO_UPLOAD" | tr -d ' ')"
delete_count="$(wc -l < "$TO_DELETE" | tr -d ' ')"
echo "Reconciliation: ${upload_count} upload/repair, ${delete_count} stale delete(s)."
if [ "$DRY_RUN" = true ]; then
  echo "Dry run: remote inventory was checked; would verify content, upload .manifest.json last, and purge cache. No R2 mutations or cache purge performed."
  exit 0
fi

upload_one() {
  IFS=$'\t' read -r key _ type cache hash <<< "$1"
  aws_r2 s3 cp "$SITE_DIR/$key" "s3://$S3_BUCKET/$key" --content-type "$type" --cache-control "$cache" --metadata "sha256=$hash" >/dev/null
}
echo "Uploading non-HTML objects..."
while IFS= read -r row; do [[ "$row" == *.html$'\t'* || "$row" == *.htm$'\t'* ]] || upload_one "$row" || { echo "ERROR: Upload failed; no deletions, manifest, or purge performed." >&2; exit 1; }; done < "$TO_UPLOAD"
echo "Uploading HTML objects..."
while IFS= read -r row; do
  if [[ "$row" == *.html$'\t'* || "$row" == *.htm$'\t'* ]]; then
    upload_one "$row" || { echo "ERROR: Upload failed; no deletions, manifest, or purge performed." >&2; exit 1; }
  fi
done < "$TO_UPLOAD"

while IFS= read -r key; do
  [ -z "$key" ] || aws_r2 s3 rm "s3://$S3_BUCKET/$key" >/dev/null || { echo "ERROR: Delete failed; manifest and purge not performed." >&2; exit 1; }
done < "$TO_DELETE"

# Re-list after every mutation and require an exact site-object inventory and metadata match.
fetch_remote
if ! diff -u <(cut -f1 "$CURRENT") <(cut -f1 "$REMOTE"); then
  echo "ERROR: Final remote key set does not match the site inventory." >&2; exit 1
fi
while IFS=$'\t' read -r key size type cache hash; do
  aws_r2 s3api head-object --bucket "$S3_BUCKET" --key "$key" --output json > "$TMP_DIR/head.json" || { echo "ERROR: Verification failed for $key." >&2; exit 1; }
  [ "$(jq -r '.ContentLength' "$TMP_DIR/head.json")" = "$size" ] \
    && [ "$(jq -r '.ContentType // ""' "$TMP_DIR/head.json")" = "$type" ] \
    && [ "$(jq -r '.CacheControl // ""' "$TMP_DIR/head.json")" = "$cache" ] \
    && [ "$(jq -r '.Metadata.sha256 // ""' "$TMP_DIR/head.json")" = "$hash" ] \
    || { echo "ERROR: Verification metadata mismatch for $key." >&2; exit 1; }
done < "$CURRENT"

jq -Rn '[inputs | split("\t") | {key: .[0], size: (.[1] | tonumber), contentType: .[2], cacheControl: .[3], sha256: .[4]}] | {schemaVersion: 1, objects: .}' < "$CURRENT" > "$TMP_DIR/manifest.json"
manifest_hash="$(sha256 "$TMP_DIR/manifest.json")"
aws_r2 s3 cp "$TMP_DIR/manifest.json" "s3://$S3_BUCKET/$MANIFEST_KEY" --content-type 'application/json; charset=utf-8' --cache-control 'public, max-age=300' --metadata "sha256=$manifest_hash" >/dev/null || { echo "ERROR: Manifest upload failed; cache not purged." >&2; exit 1; }

response="$TMP_DIR/purge.json"
http_code="$(curl -sS -o "$response" -w '%{http_code}' -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" -H "Authorization: Bearer $CF_TOKEN" -H 'Content-Type: application/json' --data '{"purge_everything":true}')" || { echo "ERROR: Cache purge request failed." >&2; exit 1; }
[ "$http_code" = 200 ] && [ "$(jq -r '.success // false' "$response")" = true ] || { echo "ERROR: Cache purge failed." >&2; exit 1; }
echo "Deployment complete: verified R2 inventory, wrote manifest last, then purged cache."
