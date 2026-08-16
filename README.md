# cyberknight-corporate-website

Corporate website for [Cyberknight Websites](https://cyberknight-websites.com), built with Jekyll and deployed to a private Cloudflare R2 bucket.

## Local Development

```bash
bundle install
./jekyll_serve_dev.sh
```

The development site runs at `http://127.0.0.1:4000/`.

## Build and Deploy

### Full pipeline

`build_www.sh` clones a fresh copy, builds Jekyll through Docker, and invokes the R2 deployment:

```bash
sudo ./build_www.sh
sudo ./build_www.sh --force-full
sudo ./build_www.sh --dry-run
```

Each build uses a unique temporary directory. Publication is serialized separately so concurrent builds cannot interleave R2 mutations.

### Deploy an existing build

`deploy.sh` reconciles `_site/` directly to stable keys in the private `cyberknight-corporate-site-production` bucket:

```bash
sudo ./deploy.sh
sudo ./deploy.sh --force-full
sudo ./deploy.sh --dry-run
```

The deployment:

1. Validates a nonempty build containing `index.html`.
2. Reads the actual remote inventory.
3. Uploads non-HTML assets before HTML.
4. Deletes stale objects only after uploads succeed.
5. Verifies keys, sizes, content types, cache metadata, and SHA-256 metadata.
6. Writes `.manifest.json` last.
7. Purges Cloudflare cache only after successful verification.

There is no `active.json`, release directory, retained release, or automated rollback. Recovery is a corrected forced full deployment.

## Requirements

- Docker and `cyberknight-council-template-builder`
- AWS CLI, Doppler CLI, `jq`, `curl`, `pass`
- `sha256sum` or `shasum`
- `cyberknight/s3-sync-doppler-token` in the operator's `pass` store, unless `DOPPLER_TOKEN` is already supplied

Doppler project `cyberknight-s3-sync`, config `prd`, supplies:

- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `CLOUDFLARE_API_TOKEN`

The R2 credentials must be restricted to `cyberknight-corporate-site-production`.

## Infrastructure

- **R2 bucket:** `cyberknight-corporate-site-production`
- **Layout:** generated site files at stable bucket-root keys
- **Manifest:** `.manifest.json`
- **Serving:** `www.cyberknight-websites.com` through the Sites Worker's `CORPORATE_R2` binding after cutover

The bucket is private and has no `r2.dev` URL or custom domain.
