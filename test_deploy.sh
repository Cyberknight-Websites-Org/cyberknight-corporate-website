#!/usr/bin/env bash
# Focused offline tests for deploy.sh. It never contacts R2, Doppler, or Cloudflare.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"; R2_ROOT="$TMP/r2"; LOG="$TMP/ops"; mkdir -p "$BIN" "$R2_ROOT"
export R2_ROOT LOG
cat > "$BIN/pass" <<'EOF'
#!/usr/bin/env bash
[ "${PASS_FAIL:-}" = 1 ] && exit 1
printf '%s\n' "${PASS_TOKEN:-pass-token}"
EOF
cat > "$BIN/doppler" <<'EOF'
#!/usr/bin/env bash
if [ -n "${DOPPLER_TOKEN:-}" ]; then
  echo 'doppler:token' >> "$LOG"
else
  echo 'doppler:cli' >> "$LOG"
fi
[ "$3" = "${MISSING_SECRET:-}" ] && exit 0
case "$3" in R2_ACCOUNT_ID) echo account;; R2_ACCESS_KEY_ID) echo key;; R2_SECRET_ACCESS_KEY) echo secret;; CLOUDFLARE_API_TOKEN) echo cf-token;; esac
EOF
cat > "$BIN/curl" <<'EOF'
#!/usr/bin/env bash
echo curl >> "$LOG"; out=""; while [ "$#" -gt 0 ]; do [ "$1" = -o ] && { out="$2"; shift 2; continue; }; shift; done; echo '{"success":true}' > "$out"; printf 200
EOF
cat > "$BIN/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "${AWS_LOG_ALL:-}" = 1 ] && echo "aws:$*" >> "$LOG"
args=(); while [ "$#" -gt 0 ]; do [ "$1" = --endpoint-url ] && { shift 2; continue; }; args+=("$1"); shift; done
set -- "${args[@]}"
if [ "$1" = s3api ] && [ "$2" = list-objects-v2 ]; then
  echo -n '{"Contents":['; first=1
  while IFS= read -r -d '' f; do
    key="${f#$R2_ROOT/}"; [[ "$key" == *.meta ]] && continue
    [ "$first" = 1 ] || echo -n ,; first=0
    jq -n --arg Key "$key" --argjson Size "$(wc -c < "$f")" '{Key:$Key,Size:$Size}'
  done < <(find "$R2_ROOT" -type f -print0)
  echo ']}'
  exit
fi
if [ "$1" = s3api ] && [ "$2" = head-object ]; then
  key=""; while [ "$#" -gt 0 ]; do [ "$1" = --key ] && { key="$2"; break; }; shift; done
  [ -f "$R2_ROOT/$key" ] || exit 1
  jq --argjson length "$(wc -c < "$R2_ROOT/$key")" '. + {ContentLength:$length}' "$R2_ROOT/$key.meta"
  exit
fi
[ "$1" = s3 ] || exit 2
if [ "$2" = cp ]; then
  src="$3"; dest="$4"; shift 4; type=""; cache=""; meta=""
  while [ "$#" -gt 0 ]; do case "$1" in --content-type) type="$2"; shift 2;; --cache-control) cache="$2"; shift 2;; --metadata) meta="$2"; shift 2;; *) shift;; esac; done
  key="${dest#s3://cyberknight-corporate-site-production/}"
  echo "cp:$key" >> "$LOG"
  [ "${FAIL_UPLOAD:-}" = "$key" ] && exit 1
  mkdir -p "$(dirname "$R2_ROOT/$key")"; cp "$src" "$R2_ROOT/$key"
  jq -n --arg ContentType "$type" --arg CacheControl "$cache" --arg sha "${meta#sha256=}" '{ContentType:$ContentType,CacheControl:$CacheControl,Metadata:{sha256:$sha}}' > "$R2_ROOT/$key.meta"
elif [ "$2" = rm ]; then
  key="${3#s3://cyberknight-corporate-site-production/}"; echo "rm:$key" >> "$LOG"; rm -f "$R2_ROOT/$key" "$R2_ROOT/$key.meta"
fi
EOF
chmod +x "$BIN"/*
export PATH="$BIN:$PATH"
unset DOPPLER_TOKEN
SITE="$TMP/site"; mkdir -p "$SITE/assets"; printf '<h1>new</h1>' > "$SITE/index.html"; printf css > "$SITE/assets/site.12345678.css"
# A stale object establishes upload-before-delete, manifest-last, and purge-last behavior.
printf old > "$R2_ROOT/old.txt"; jq -n '{ContentType:"text/plain; charset=utf-8",CacheControl:"public, max-age=300",Metadata:{sha256:"old"}}' > "$R2_ROOT/old.txt.meta"
run_site() { DEPLOY_LOCK_DIR="$TMP/lock" SITE_DIR="$1" "$ROOT/deploy.sh" "${@:2}" >/dev/null; }
run() { run_site "$SITE" "$@"; }
# Site inventory safety gates run before any R2 or Cloudflare operation.
EMPTY_SITE="$TMP/empty"; mkdir "$EMPTY_SITE"; : > "$LOG"
if run_site "$EMPTY_SITE"; then exit 1; fi
! grep -q -E '^(aws:|curl$)' "$LOG"
MISSING_INDEX_SITE="$TMP/missing-index"; mkdir "$MISSING_INDEX_SITE"; printf nope > "$MISSING_INDEX_SITE/not-index.html"; : > "$LOG"
if run_site "$MISSING_INDEX_SITE"; then exit 1; fi
! grep -q -E '^(aws:|curl$)' "$LOG"
UNSAFE_SITE="$TMP/unsafe"; mkdir "$UNSAFE_SITE"; printf nope > "$UNSAFE_SITE/"$'bad\tname.txt'; printf ok > "$UNSAFE_SITE/index.html"; : > "$LOG"
if run_site "$UNSAFE_SITE"; then exit 1; fi
! grep -q -E '^(aws:|curl$)' "$LOG"
# Doppler uses an explicit token first, then pass, then the authenticated CLI.
: > "$LOG"; DOPPLER_TOKEN=environment-token PASS_FAIL=1 run --dry-run
[ "$(grep -c '^doppler:token$' "$LOG")" = 4 ] && ! grep -q '^doppler:cli$' "$LOG"
: > "$LOG"; PASS_TOKEN=pass-token run --dry-run
[ "$(grep -c '^doppler:token$' "$LOG")" = 4 ] && ! grep -q '^doppler:cli$' "$LOG"
: > "$LOG"; (unset DOPPLER_TOKEN; PASS_FAIL=1 run --dry-run)
[ "$(grep -c '^doppler:cli$' "$LOG")" = 4 ] && ! grep -q '^doppler:token$' "$LOG"
# Every Doppler value, including the Cloudflare token, is validated before R2 mutation.
: > "$LOG"
if MISSING_SECRET=CLOUDFLARE_API_TOKEN AWS_LOG_ALL=1 run; then exit 1; fi
[ "$(grep -c '^doppler:token$' "$LOG")" = 4 ] && ! grep -q '^aws:' "$LOG"
run
[ -f "$R2_ROOT/index.html" ] && [ -f "$R2_ROOT/.manifest.json" ] && [ ! -f "$R2_ROOT/old.txt" ]
first_cp=$(grep -n '^cp:' "$LOG" | head -1 | cut -d: -f1); first_rm=$(grep -n '^rm:' "$LOG" | head -1 | cut -d: -f1); manifest=$(grep -n '^cp:.manifest.json' "$LOG" | cut -d: -f1); purge=$(grep -n '^curl$' "$LOG" | cut -d: -f1)
asset=$(grep -n '^cp:assets/site.12345678.css$' "$LOG" | cut -d: -f1); html=$(grep -n '^cp:index.html$' "$LOG" | cut -d: -f1)
[ "$asset" -lt "$html" ] && [ "$first_cp" -lt "$first_rm" ] && [ "$first_rm" -lt "$manifest" ] && [ "$manifest" -lt "$purge" ]
# A no-op run still verifies content, rewrites the manifest, and retries cache purging.
: > "$LOG"; run
! grep -q '^cp:index.html$' "$LOG" && ! grep -q '^cp:assets/site.12345678.css$' "$LOG" && ! grep -q '^rm:' "$LOG"
grep -q '^cp:.manifest.json$' "$LOG" && grep -q '^curl$' "$LOG"
# Missing remote objects are repaired even though the previous manifest exists.
rm "$R2_ROOT/assets/site.12345678.css" "$R2_ROOT/assets/site.12345678.css.meta"; : > "$LOG"; run; grep -q '^cp:assets/site.12345678.css$' "$LOG"
# Force-full uploads current objects and still removes stale keys.
printf stale > "$R2_ROOT/stale.txt"; jq -n '{ContentType:"x",CacheControl:"x",Metadata:{sha256:"x"}}' > "$R2_ROOT/stale.txt.meta"; : > "$LOG"; run --force-full; grep -q '^cp:index.html$' "$LOG"; grep -q '^rm:stale.txt$' "$LOG"
# Upload errors gate deletion, manifest write, and purge.
printf stale > "$R2_ROOT/stale2.txt"; jq -n '{ContentType:"x",CacheControl:"x",Metadata:{sha256:"x"}}' > "$R2_ROOT/stale2.txt.meta"; printf changed > "$SITE/index.html"; : > "$LOG"
if FAIL_UPLOAD=index.html run; then exit 1; fi
! grep -q '^rm:' "$LOG" && ! grep -q '^cp:.manifest.json' "$LOG" && ! grep -q '^curl$' "$LOG"
# Dry runs inspect inventory but do not mutate or purge; an existing lock fails closed.
: > "$LOG"; run --dry-run; ! grep -q -E '^(aws:|curl$|cp:|rm:)' "$LOG"
mkdir "$TMP/lock"; if run --dry-run 2>/dev/null; then exit 1; fi; rmdir "$TMP/lock"
echo "deploy.sh focused tests passed"
