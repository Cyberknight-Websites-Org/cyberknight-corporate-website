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

FORCE_FULL=false
for arg in "$@"; do
  case "$arg" in
    --force-full)
      FORCE_FULL=true
      ;;
    *)
      echo "ERROR: Unknown argument '$arg'. Usage: $0 [--force-full]"
      exit 1
      ;;
  esac
done

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
# Deploy to S3 + Cloudflare
# ---------------------------------------------------------------------------

STEP_START=$(get_timestamp)
DEPLOY_ARGS=""
if [ "$FORCE_FULL" = true ]; then
  DEPLOY_ARGS="--force-full"
fi

./deploy.sh $DEPLOY_ARGS
if [ $? -ne 0 ]; then
  echo "ERROR: Deploy failed. Exiting."
  exit 1
fi
DEPLOY_TIME=$(perl -e "printf '%.2f', $(get_timestamp) - $STEP_START")

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
echo "  3. Deploy:             ${DEPLOY_TIME}s"
