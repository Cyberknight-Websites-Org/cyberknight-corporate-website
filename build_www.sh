#!/bin/bash

# Build and deploy www.cyberknight-websites.com to S3 + Cloudflare
# Usage: ./build_www.sh
#
# Credentials are injected via Doppler (cyberknight-s3-sync / prd).
# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and CLOUDFLARE_API_TOKEN
# must all be present in that Doppler project.

JEKYLL_BUILDER_IMAGE="cyberknight-council-template-builder"
REPO_URL="https://github.com/Cyberknight-Websites-Org/cyberknight-corporate-website.git"
JEKYLL_DIR="/tmp/cyberknight-www-build"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

get_timestamp() {
  perl -MTime::HiRes=time -e 'printf "%.2f", time'
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

if [ -w "$HOME/logs" ]; then
  LOG_DIR="$HOME/logs/cyberknight-www"
else
  LOG_DIR="./logs"
fi
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$LOG_DIR/build_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

START_TIME=$(get_timestamp)
echo "=== Build started at $(date) ==="

# ---------------------------------------------------------------------------
# Doppler token
# ---------------------------------------------------------------------------

export DOPPLER_TOKEN="$(pass show cyberknight/s3-sync-doppler-token)"

if [ -z "$DOPPLER_TOKEN" ]; then
  echo "ERROR: Could not retrieve Doppler token from pass. Exiting."
  exit 1
fi

# ---------------------------------------------------------------------------
# Clone repository
# ---------------------------------------------------------------------------

STEP_START=$(get_timestamp)
if [ -d "$JEKYLL_DIR" ]; then
  rm -rf "$JEKYLL_DIR"
fi
mkdir -p "$JEKYLL_DIR"

echo "Cloning repository..."
git clone --depth 1 "$REPO_URL" "$JEKYLL_DIR"
if [ $? -ne 0 ]; then
  echo "ERROR: Git clone failed. Exiting."
  exit 1
fi
CLONE_TIME=$(perl -e "printf '%.2f', $(get_timestamp) - $STEP_START")

cd "$JEKYLL_DIR"

# ---------------------------------------------------------------------------
# Jekyll build
# ---------------------------------------------------------------------------

echo "Building Jekyll site..."
STEP_START=$(get_timestamp)
docker run --rm \
  -v "$JEKYLL_DIR:/srv/jekyll" \
  -u $(id -u):$(id -g) \
  "$JEKYLL_BUILDER_IMAGE" \
  bundler exec jekyll build
DOCKER_EXIT_CODE=$?
BUILD_TIME=$(perl -e "printf '%.2f', $(get_timestamp) - $STEP_START")
echo "  → Build completed with exit code $DOCKER_EXIT_CODE in ${BUILD_TIME}s"

if [ $DOCKER_EXIT_CODE -ne 0 ]; then
  echo "ERROR: Jekyll build failed. Exiting."
  exit 1
fi

# ---------------------------------------------------------------------------
# Sync to S3
# ---------------------------------------------------------------------------

echo "Syncing to S3..."
STEP_START=$(get_timestamp)
doppler run --project cyberknight-s3-sync --config prd -- \
  aws s3 sync "$JEKYLL_DIR/_site/" s3://cyberknight-websites/www/ --delete
if [ $? -ne 0 ]; then
  echo "ERROR: S3 sync failed. Exiting."
  exit 1
fi
SYNC_TIME=$(perl -e "printf '%.2f', $(get_timestamp) - $STEP_START")

# ---------------------------------------------------------------------------
# Purge Cloudflare cache
# ---------------------------------------------------------------------------

echo "Purging Cloudflare cache..."
STEP_START=$(get_timestamp)
CF_TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN --project cyberknight-s3-sync --config prd --plain)

CF_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "https://api.cloudflare.com/client/v4/zones/9dbd179caf99bb5fd469db1545fbb431/purge_cache" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"prefixes": ["www.cyberknight-websites.com/"]}')
PURGE_TIME=$(perl -e "printf '%.2f', $(get_timestamp) - $STEP_START")

if [ "$CF_HTTP_CODE" != "200" ]; then
  echo "WARNING: Cloudflare cache purge returned HTTP $CF_HTTP_CODE."
else
  echo "  → Cache purge complete (HTTP $CF_HTTP_CODE) in ${PURGE_TIME}s"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

END_TIME=$(get_timestamp)
DURATION=$(perl -e "printf '%.2f', $END_TIME - $START_TIME")

echo ""
echo "=== Build completed at $(date) ==="
echo "=== Total build time: ${DURATION}s ==="
echo ""
echo "Step-by-step breakdown:"
echo "  1. Git clone:          ${CLONE_TIME}s"
echo "  2. Jekyll build:       ${BUILD_TIME}s"
echo "  3. S3 sync:            ${SYNC_TIME}s"
echo "  4. Cache purge:        ${PURGE_TIME}s"
