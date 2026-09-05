#!/bin/bash

# Build and deploy www.cyberknight-websites.com to R2 + Cloudflare.
# Usage: ./build_www.sh [--force-full] [--dry-run]
# Credentials are read by deploy.sh from Doppler (cyberknight-s3-sync / prd).

JEKYLL_BUILDER_IMAGE="cyberknight-council-template-builder"
REPO_URL="https://git.cyberknight-websites.com/julianlopez/cyberknight-corporate-website.git"
JEKYLL_DIR=""

DEPLOY_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --force-full|--dry-run) DEPLOY_ARGS+=("$arg") ;;
    *)
      echo "ERROR: Unknown argument '$arg'. Usage: $0 [--force-full] [--dry-run]"
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
# Clone repository
# ---------------------------------------------------------------------------

JEKYLL_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cyberknight-www-build.XXXXXX")" || {
  echo "ERROR: Could not create build directory. Exiting."
  exit 1
}
cleanup() {
  status=$?
  [ -z "$JEKYLL_DIR" ] || rm -rf -- "$JEKYLL_DIR"
  trap - EXIT INT TERM
  exit "$status"
}
trap cleanup EXIT INT TERM

STEP_START=$(get_timestamp)
echo "Cloning repository..."
GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$REPO_URL" "$JEKYLL_DIR"
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
# Deploy to R2 + Cloudflare
# ---------------------------------------------------------------------------

STEP_START=$(get_timestamp)
./deploy.sh "${DEPLOY_ARGS[@]}"
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
