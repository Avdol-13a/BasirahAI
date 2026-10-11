# BasirahAI Inference Backend

Stateless FastAPI service that validates retinal fundus images and returns a Referable / Non-Referable screening result. Authentication, patient records, and screening history remain in Supabase; the Flutter app writes results there directly.

This is screening support, not a medical diagnosis.

## Current deployment: AWS Lightsail

Migrated from Railway on **October 10, 2026** after the trial ended. Supabase was resumed, and the AWS-connected Android build was confirmed working on a real device.

- Instance: `Basirah-api`, Ubuntu 24.04 LTS, 2 GB RAM, dual-stack networking.
- Static public IPv4: `18.141.92.11`.
- API: https://18-141-92-11.sslip.io
- HTTPS: Caddy reverse proxy with automatically managed certificates; `sslip.io` resolves the hostname to the static IP.
- Runtime: Docker Compose, one backend process, CPU-only PyTorch. Both model artifacts are included during the image build, so startup does not need to download them.
- Verified October 11, 2026: `/health` reports both models loaded. A blank-image request was also verified to return the structured `too_dark` rejection during deployment on October 10.

The backend has no persistent patient database and does not retain uploaded photos after processing. Caddy certificate state is retained in Docker volumes.

## Endpoints

- `GET /health` returns `{"status":"ok","model_loaded":true,"fundus_gate_loaded":true}` when both models are loaded.
- `POST /screen` accepts multipart field `image` (JPEG/PNG) and returns `referable`, `confidence`, `raw_grade`, `raw_grade_label`, `class_probabilities`, and `quality_warnings`.
- Invalid or unsuitable images receive an error response. Image suitability errors include a stable `detail.code` and a readable `detail.message` for the app's localized handling.

## Deploy on Lightsail

1. Create an Ubuntu 24.04 Linux instance with 2 GB RAM and attach a static IPv4 address. Allow inbound TCP 80 and 443 for HTTP/HTTPS; retain SSH access for administration. The backend's port 7860 stays internal to Docker.
2. In the server terminal, install Docker and Git:

   ```bash
   sudo apt-get update
   sudo apt-get install -y docker.io docker-compose-v2 git curl
   sudo systemctl enable --now docker
   ```

3. Clone the project and build the backend:

   ```bash
   git clone https://github.com/Avdol-13a/BasirahAI.git
   cd BasirahAI/backend
   sudo docker compose build backend
   ```

4. Replace the Azure placeholder in `Caddyfile` with the following configuration **on the existing server**. For a different server, use a hostname resolving to that server's static IP instead:

   ```caddyfile
   18-141-92-11.sslip.io {
       reverse_proxy backend:7860
   }
   ```

5. Start the services and verify them:

   ```bash
   sudo docker compose up -d
   sudo docker compose logs --tail=40
   curl --fail https://18-141-92-11.sslip.io/health
   ```

The initial build downloads dependencies and exports the DR model and fundus backbone. Allow time for the build, startup, and certificate issuance. Both services use `restart: unless-stopped`.

## Connect the Android app

From the repository's `app/` directory:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=<your-existing-supabase-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-public-anon-key> \
  --dart-define=BACKEND_URL=https://18-141-92-11.sslip.io \
  --build-name=1.0.2 --build-number=3
```

Use the existing Supabase project. Never embed its service-role key in the app. The explicit `BACKEND_URL` overrides any older Railway default in a checkout. Already installed APKs need to be rebuilt/replaced to change their endpoint.

## Operations

- Inspect service state with `sudo docker compose ps` and logs with `sudo docker compose logs --tail=100` from the backend directory.
- Keep the static IP attached and preserve the `caddy_data` and `caddy_config` volumes so certificates survive restarts.
- Before rebuilding after a source update, preserve the server's customized `Caddyfile`; the repository still contains a placeholder. Rebuild with `sudo docker compose build backend`, then run `sudo docker compose up -d` and check `/health`.
- Monitor AWS credit balance, expiry, and usage in Billing. Configure budget alerts; they are notifications, not a spending cap. Credit coverage and account-plan limits depend on the account.
- Supabase Free can pause during inactivity. Check authentication and database access before a demo and resume the project if necessary.

## Local development and tests

For a local container, build with `docker build -t basirah-api .`, then run `docker run --rm -p 8000:7860 basirah-api`. Check `http://localhost:8000/health`. This includes the model export steps required by the runtime.

Backend tests mock model loading/inference and do not download checkpoints:

```bash
python -m venv .venv
# Activate .venv using the command appropriate to your shell.
pip install --no-cache-dir torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cpu
pip install -r requirements.txt -r requirements-dev.txt
python -m pytest tests/ -v
```

The GitHub Actions workflow also runs backend tests, Flutter analysis, and Flutter tests.

## Previous hosting configurations

`railway.json`, the root `render.yaml`, and the Azure-style placeholder in `Caddyfile` are retained from earlier hosting work. They do not describe the current deployment. Historical experiments are recorded in `dev/HANDOFF.md` and `dev/plan.md`; their trial, pricing, and availability claims should not be treated as current offers.
