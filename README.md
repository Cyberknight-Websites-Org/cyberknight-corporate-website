# cyberknight-corporate-website

Corporate website for [Cyberknight Websites](https://cyberknight-websites.com), built with Jekyll and deployed to S3 + Cloudflare.

## Local Development

```bash
bundle install
./jekyll_serve_dev.sh
# Site served at http://127.0.0.1:4000/
```

## Build and Deploy

### `build_www.sh` — full pipeline (clone → build → deploy)

Intended for production use. Clones a fresh copy of the repository, builds the Jekyll site via Docker, and deploys to S3 with Cloudflare cache purge.

```bash
sudo ./build_www.sh
```

**Options:**
- `--force-full` — skip the manifest diff and re-upload all files regardless of what changed

```bash
sudo ./build_www.sh --force-full
```

**Requirements:** must be run as root. Requires Docker, the `cyberknight-council-template-builder` Docker image, and the `cyberknight/s3-sync-doppler-token` key in the root `pass` store.

Logs are written to `~/logs/cyberknight-www/build_TIMESTAMP.log` (or `./logs/` if that directory is not writable).

---

### `deploy.sh` — deploy only (no clone or build)

Deploys an existing `_site/` directory to S3 using a manifest-based diff — only files that have changed since the last deploy are uploaded or deleted. Purges only the affected URLs from Cloudflare's cache.

```bash
sudo ./deploy.sh
```

**Options:**
- `--force-full` — skip the manifest diff and re-upload all files

```bash
sudo ./deploy.sh --force-full
```

**Requirements:** must be run as root. Requires `aws`, `doppler`, `jq`, `sha256sum`, `curl`, `pass`, and `perl` in PATH, and the `cyberknight/s3-sync-doppler-token` key in the root `pass` store.

Logs are written to `~/logs/cyberknight-www/deploy_TIMESTAMP.log` (or `./logs/` if that directory is not writable).

---

## Infrastructure

- **S3 bucket:** `cyberknight-websites`, folder `www/`
- **Cloudflare zone:** `www.cyberknight-websites.com`
- **Credentials:** managed via Doppler project `cyberknight-s3-sync`, config `prd`
- **Manifest:** stored at `s3://cyberknight-websites/www/.manifest.json`
