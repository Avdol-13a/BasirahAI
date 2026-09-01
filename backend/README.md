# BasirahAI Inference Backend

Stateless FastAPI service that wraps a pretrained diabetic retinopathy
screening model. See the project's `docs/ML_PLAN.md` and `dev/plan.md` (repo
root) for full context — this backend does one job: validate an uploaded
retinal photo and return a Referable / Non-Referable screening result.

This is a screening/decision-support signal, not a medical diagnosis.

## Endpoints

- `GET /health` — `{"status": "ok", "model_loaded": true}`
- `POST /screen` — multipart form field `image` (jpeg/png) →
  `{"referable": bool, "confidence": float, "raw_grade": 0-4, "raw_grade_label": str, "class_probabilities": [float x5]}`

## Current deployment targets

The runtime uses plain PyTorch rather than retaining the full fastai Learner.
The original learner and the optimized runtime have been checked at tensor and
logit level; differences are limited to floating-point noise. Total FastAPI
memory after a prediction measured approximately 483 MB, allowing it to run on
Render's 512 MB Free instance.

### Railway (immediate 30-day trial)

Railway can deploy this directory directly. `railway.json` selects the
Dockerfile and allows five minutes for the model-loading health check. The
Dockerfile honors Railway's injected `PORT` variable. Enable Serverless mode so
the $5 trial credit is not consumed while the API is idle.

```bash
cd backend
railway login
railway init
railway up
railway domain
```

### Render Free (long-term target)

The repository-root `render.yaml` defines the free Docker web service. Connect
the repository as a Blueprint in Render. Free services sleep after 15 minutes;
the first screening after sleep must wait for model startup.

## Azure fallback

Hugging Face Spaces (the original hosting plan) now requires a paid Pro
plan for any Space that runs compute — confirmed dead end as of Aug 2026,
see `dev/plan.md`. **Azure for Students** gives $100 of credit for 12 months
with **no credit card required** (verify via school email, or via the
GitHub Student Developer Pack if the school email isn't recognized) — this
project's real memory footprint (~550MB with the model loaded, measured
directly) needs more RAM than most truly-free-forever tiers offer, so a
small Azure VM is the most realistic option that costs nothing out of
pocket. A `B1s` or `B2s` VM (1-4GB RAM) costs a few dollars a month —
comfortably inside the $100 credit for the whole hackathon and well beyond.

## Deploying to an Azure for Students VM

1. **Activate Azure for Students** at [azure.microsoft.com/free/students](https://azure.microsoft.com/en-us/free/students) — sign in with your school email, or with your GitHub account if you have the GitHub Student Developer Pack.
2. **Create a Linux VM** (Azure Portal → Create a resource → Virtual Machine):
   - Image: **Ubuntu Server 24.04 LTS**
   - Size: **B2s** (2 vCPU, 4GB RAM) — comfortable headroom over our ~550MB footprint
   - Authentication: SSH public key (Azure can generate a key pair for you — download and keep the private key)
   - Under **Networking**, allow inbound ports **22 (SSH), 80 (HTTP), 443 (HTTPS)**
3. **Set a DNS name label** so you get free HTTPS without buying a domain: after the VM is created, go to its **Overview** page → **DNS name** → **Configure** → pick a label (e.g. `basirahai`). Your public URL becomes something like `basirahai.eastus.cloudapp.azure.com`.
4. **Edit `Caddyfile`** in this folder — replace the placeholder domain with your actual VM's DNS name from step 3.
5. **SSH into the VM** and install Docker:
   ```bash
   ssh -i /path/to/your-key.pem azureuser@<your-vm-public-ip>
   curl -fsSL https://get.docker.com | sudo sh
   sudo usermod -aG docker $USER
   # log out and back in for the group change to apply
   ```
6. **Copy this `backend/` folder to the VM** (from your own machine):
   ```bash
   scp -i /path/to/your-key.pem -r backend azureuser@<your-vm-public-ip>:~/basirah-backend
   ```
7. **On the VM, start everything:**
   ```bash
   cd ~/basirah-backend
   sudo docker compose up -d --build
   ```
8. **Verify:** `https://<your-dns-label>.<region>.cloudapp.azure.com/health` should return `{"status": "ok", "model_loaded": true}` within a minute or two (Caddy needs a moment to get its first Let's Encrypt certificate, and the container needs to download+load the model on first start).

**Set a spending alert.** In the Azure Portal, go to **Cost Management → Budgets** and set an alert well under $100 (e.g. $20) so you get warned long before the student credit could run out — you shouldn't come close to this running one small VM for a week, but it's a free safety net.

## Running locally (for development/testing, not deployment)

```bash
python -m venv .venv
source .venv/Scripts/activate   # Windows Git Bash; use .venv/bin/activate on Linux/Mac
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```
