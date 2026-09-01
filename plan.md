# BasirahAI — Project Plan

_Alibaba Cloud AI Hackathon Pakistan 2026 (Bano Qabil × Alibaba Cloud) — build phase closes 2026-09-04_

> **Hosting note (2026-08-31):** Azure verification never cleared, so the optimized backend is now live on Railway's $5/30-day trial at `https://basirahai-api-production.up.railway.app`. This is enough for the hackathon month but is not permanent free hosting.

Keep this file open while you work. This is the practical, living checklist. `docs/` holds the supporting detail docs referenced below.

> **This plan replaced an earlier on-device/self-trained-model architecture.** BasirahAI is now a cloud-inference, account-based, patient-record-keeping screening app using an existing pretrained model via a remote API — not on-device inference, not a model we trained ourselves. If you find old references to TFLite, on-device inference, or self-training anywhere, they're stale — this file and `docs/` are the current source of truth.

## Project Overview

BasirahAI is a Flutter mobile app for diabetic-retinopathy screening support in Pakistan. A user (or health worker) creates an account, adds a patient, captures/uploads a retinal fundus photo, and the photo is uploaded over HTTPS to a FastAPI backend that runs an existing pretrained model and returns a **Referable / Non-Referable** result with a confidence score. Patient records and screening history are stored in Supabase, scoped per authenticated user. English + Urdu, with correct RTL layout. This is a screening/decision-support tool, not a diagnosis — every result says so.

## Goals

- A real, working pretrained AI model running in a live cloud backend — not a mockup, not trained by us.
- Real image upload from the phone over HTTPS to that backend, with graceful handling of weak/interrupted connections.
- Authenticated users, patient records (including optional CNIC), and screening history, persisted in Supabase.
- Genuine English + Urdu support with correct RTL layout.
- Honest, non-fabricated safety messaging and evaluation numbers throughout — our own measured numbers kept clearly separate from the model author's published numbers.
- A working, installable release APK, demoable on a real Android phone over real mobile data, by Sep 4.

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Mobile app | Flutter (Dart) | Best Urdu/RTL localization story; unchanged from earlier planning, no ML-framework reason to switch |
| HTTP client | `dio` | Built-in upload-progress callbacks, needed for the upload-progress requirement |
| Auth / DB / Storage | Supabase (free tier), via `supabase_flutter` | One provider covers auth + patient records + history with an official Flutter SDK and Row-Level Security — minimal custom backend code |
| Inference backend | FastAPI (Python), Docker | One endpoint (`/screen`), stateless, easy to reason about |
| Model | [jdelgado2002/diabetic_retinopathy_detection](https://huggingface.co/jdelgado2002/diabetic_retinopathy_detection) — ResNet-50 via fastai, **MIT license**, trained on APTOS 2019 | Clear license + clear provenance; 5-class output collapses onto the same Referable/Non-Referable cut point already used in `docs/MEDICAL_SAFETY.md`; see `docs/ML_PLAN.md` |
| Backend hosting | **Railway trial** (Docker, serverless sleep enabled) | The runtime was reduced to ~483MB by removing fastai from inference. Railway supplies enough RAM and a $5/30-day trial; Azure verification remains pending. |
| Localization | `flutter_localizations` + `intl`, ARB files | Unchanged from earlier planning |

**No self-training, no on-device inference.** The phone never runs the model — see `docs/ML_PLAN.md`.

## Architecture

```
Flutter App ── auth / patients / history ──▶ Supabase (Postgres + Auth + Storage)
Flutter App ── HTTPS multipart upload ──▶ FastAPI /screen ──▶ pretrained model ──▶ result
                                                                                       │
                                              Flutter writes the result to Supabase ◀──┘
```

Full diagram and reasoning: this file's git history / conversation record, and `docs/ML_PLAN.md`.

## Repository Structure

```
basirah/
├── plan.md
├── .gitignore
├── docs/                      # DATASET.md, ML_PLAN.md, EVALUATION_RESULTS.md,
│                               # IMAGE_PIPELINE.md, MEDICAL_SAFETY.md (reused as-is),
│                               # BASIRAH_HANDBOOK.md (historical — old architecture, kept for reference)
├── backend/                   # FastAPI inference service (DONE — see Current Status)
│   ├── app/
│   │   ├── main.py            # /health, /screen
│   │   └── model.py           # loads the pretrained model, runs predict()
│   ├── Dockerfile
│   ├── requirements.txt
│   └── README.md              # deployment notes (being updated for Azure)
└── app/                       # Flutter project (not yet scaffolded — Day 3+)
```

## Prerequisites

- Git for Windows, GitHub account
- Python 3.10+ (backend already built/tested with 3.11)
- A Supabase account (free tier) — no credit card required
- An **Azure for Students** account (aka.ms/azureforstudents) — $100 credit, 12 months, no credit card required; verify via school email, or via the GitHub Student Developer Pack if the school email isn't recognized
- Flutter SDK + Android SDK — **done**, installed at `D:\flutter` and `D:\Android`
- A real Android phone (recommended over emulator, and required for the real-mobile-data demo requirement)

## Environment Variables

- **Backend:** none required for the MVP — the model loads from the public Hugging Face Hub at container startup, no API keys involved. If this ever changes, values go in a `.env`, never committed (already covered by `.gitignore`).
- **Flutter app:** Supabase URL + anon key (public, safe to embed in the app — Supabase's security model relies on Row-Level Security, not on the anon key being secret). Still keep them out of version-controlled example files if you'd rather not hardcode them directly in `main.dart` — a `.env` read via `flutter_dotenv` is fine but not strictly required for an anon key.

## Development Setup

1. `git init` inside `D:\basirah`, create the GitHub repo, connect it, push.
2. `.gitignore` already created (backend venv, secrets, Flutter build artifacts).
3. Backend already scaffolded and tested locally (`backend/`) — see Current Status.

---

## Current Status

- [x] Repo skeleton (`docs/`, `backend/`, `.gitignore`)
- [x] Pretrained model verified loading locally (`from_pretrained_fastai`, with the Windows pickle shim + `get_x`/`get_y` stubs documented in `backend/app/model.py`)
- [x] `POST /screen` and `GET /health` implemented and tested locally (TestClient — real inference, real error handling for bad/empty files)
- [x] Measured real memory footprint (~550MB with model loaded) — ruled out Render's free tier (512MB) before wasting time deploying there
- [x] Flutter SDK + Android SDK installed and verified (`flutter doctor` clean for Android)
- [x] Flutter app scaffolded (`flutter create`), core dependencies added (`dio`, `supabase_flutter`, `image_picker`, `image`)
- [x] Auth screens (login/signup), patient list/detail/form screens, screening capture + result screens, all wired to Supabase and the inference backend — `flutter analyze` clean, widget test passes (code complete, not yet tested against a real deployed backend or real Supabase project — waiting on Azure + your Supabase keys)
- [x] `supabase/schema.sql` written (patients + screenings tables, RLS policies) — ready to paste into the Supabase SQL Editor
- [x] Debug APK builds successfully end-to-end (`flutter build apk --debug`) — confirms the whole Android toolchain + all plugins actually compile together, not just `flutter analyze` passing. Hit and fixed a real Windows-only Kotlin incremental-compiler bug along the way (`android/gradle.properties` now sets `kotlin.incremental=false` — documented there, don't remove without knowing why)
- [x] Real Supabase project connected and fully verified end-to-end on the emulator: sign-up, login, and patient creation/listing all confirmed working against the live project with your real account (avdol764@gmail.com). Found and fixed a real bug along the way — `schema.sql`'s RLS policies alone weren't enough; the `authenticated` role also needed explicit `GRANT SELECT/INSERT/UPDATE/DELETE` on both tables (Postgres error 42501). `schema.sql` now includes those grants. "Confirm email" is off in the Supabase project (dev convenience, under Authentication → Sign In / Providers → User Signups, not the Email provider panel).
- [x] Temporary hosting selected after Azure delay: Railway $5/30-day trial
- [x] Backend deployed to public HTTPS: `https://basirahai-api-production.up.railway.app`
- [x] Live `/health` and `/screen` verified; warm requests measured at ~0.72s and ~0.74s respectively on 2026-08-31
- [x] Full Flutter flow tested end-to-end against live Railway backend + live Supabase on the Android emulator (2026-08-31): capture → upload → inference → result → saved to patient history, confirmed with a synthetic test image (real APTOS images still needed for the accuracy evaluation below). Found and fixed a real bug along the way — see Troubleshooting Notes.
- [x] Independent sanity-check evaluation run against real APTOS sample images (2026-08-31, 201 images, 0 errors) — **but see the important caveat in `docs/EVALUATION_RESULTS.md`: the sample necessarily came from `train.csv` (the only publicly-labeled APTOS split), which the model almost certainly trained on, so the measured 98.5% accuracy is not a genuine held-out-generalization number and must not be presented as "beating" the author's self-reported 0.840.** Low-confidence cutoff (0.6 placeholder) still not validated — see below.
- [x] Supabase project created, schema + RLS policies applied (done earlier — see §6/§10 of HANDOFF.md; this checklist just hadn't been ticked)
- [x] Flutter app scaffolded
- [x] Auth screens (login/signup)
- [x] Patient CRUD screens
- [x] Screening capture → upload → result flow (talking to the real deployed backend) — verified 2026-08-31 on emulator, not yet on a real device (see below)
- [x] Screening history
- [x] Visual redesign ("Warm Earth & Trust" direction — deep indigo primary, terracotta accent for screening-specific CTAs, sage-green/vermillion/cool-gray for the three result states, Lora + Manrope typefaces). Drafted as a design canvas mockup, then implemented across all 7 screens in `app/lib/theme/app_theme.dart` (shared tokens) — logic/state untouched, `flutter analyze` and `flutter test` both clean, verified visually on the emulator against a real session. Fonts bundled locally as static assets (`app/assets/fonts/`, SIL OFL license) rather than via the `google_fonts` package, which pulls in native-asset dependencies that need Windows Developer Mode to build on this machine.
- [x] Urdu/RTL localization — `flutter_localizations` + `intl`, ARB-based (`app/lib/l10n/app_en.arb`, `app_ur.arb`, gen-l10n via `app/l10n.yaml`). All 7 screens fully localized, including backend-error messages (`InferenceException` now carries an `InferenceErrorCode` enum instead of hardcoded English so the UI layer picks the localized string; the backend's own `detail` field, when present, stays English since the backend itself doesn't localize — documented in `inference_service.dart`). App-wide language toggle (`lib/widgets/language_toggle_button.dart`) on the Login and Patients screens, in-memory only (resets to English on cold start — no `shared_preferences` dependency added, to avoid another potential Windows-Developer-Mode build blocker; a reasonable trade-off for the hackathon timeline, revisit if there's time). Verified visually on the emulator in both languages: RTL mirroring correct throughout (directional icons flipped via `Transform.flip` — `Icon`'s `matchTextDirection` doesn't actually exist, don't reach for it again; `Positioned`/`Padding` use `*Directional` variants), and one real bidi bug found and fixed — a raw LTR timestamp with an internal space was getting visually reordered when embedded in Urdu text; fixed with U+200E LRM marks (`patient_detail_screen.dart`).
- [x] Full manual test pass
- [x] Release APK built and verified on a real phone over real mobile data (2026-09-01) — found and fixed a real release-only bug along the way (see Troubleshooting Notes): the release APK was missing `android.permission.INTERNET` entirely, causing every Supabase call to fail with a raw `SocketException: Failed host lookup`. Login, patient list, screening capture → Railway inference → result → history save, and the EN/UR toggle all verified working on a real Android phone (Realme RMX5303) over real mobile LTE data after the fix.
- [ ] `docs/DATASET.md`, `docs/ML_PLAN.md`, `docs/EVALUATION_RESULTS.md`, `docs/IMAGE_PIPELINE.md` rewritten for this architecture
- [ ] Demo rehearsed

## Critical Path (in order — everything else is negotiable)

1. Pretrained model loads and runs — **done**
2. `/screen` endpoint works locally — **done**
3. Backend deployed and reachable over the public internet
4. Flutter app can upload a real photo to the real deployed backend and show a real result
5. Auth + patient records + history work and are correctly isolated per user (Supabase RLS)
6. English + Urdu both work correctly across the full app
7. Release APK works standalone on a real phone over real mobile data

If time runs out, everything below "Optional Features" is cut before anything on this list is touched.

## Optional Features (cut first if time is short)

- Storing a compressed image thumbnail with each history entry (default is to NOT retain the raw image at all — see `docs/DATASET.md`/security notes)
- Displaying the raw 5-stage grade as secondary detail beyond the binary result
- App icon/splash branding, UI animation polish
- iOS support (not attempted)
- Tightening CORS beyond the permissive development default, if time is short (acceptable risk for a hackathon demo, not for production)

## Testing Checklist

- [x] Clear fundus photo → correct Referable/Non-Referable result with confidence (EN + UR) — verified repeatedly throughout 2026-08-31 testing (synthetic test images; real fundus photos still pending the real-device pass)
- [x] Bad/non-image file upload → clear 400 error, shown to the user, no crash — verified 2026-08-31 directly against the live backend (`{"detail":"This doesn't look like a valid image file."}`, HTTP 400); the real photo picker can't actually hand the app a non-image file (OS picker only lists images), so this is backend-confirmed rather than end-to-end-UI-confirmed — the display code path is identical to the other error cases below, which *are* UI-confirmed
- [x] Empty file upload → clear 400 error — verified 2026-08-31 directly against the live backend (`{"detail":"Uploaded file is empty."}`); same picker caveat as above
- [x] Oversized file (>10MB) → clear 413 error — backend confirmed directly (`{"detail":"Image is too large (max 10 MB)."}`, HTTP 413) on 2026-08-31. **Finding:** this path is effectively unreachable through the real app UI — `image_picker`'s `imageQuality: 90` client-side re-compression shrinks even a 16.7MB source image well under 10MB before upload, so a real user is very unlikely to ever hit this. Not a bug, just means the app's own behavior protects against it in practice.
- [ ] Backend cold start (first request after idle) → app shows a loading/retry state, not a silent failure — not exercised 2026-08-31 (Railway backend was warm throughout testing); worth checking once closer to the demo if the backend has been idle
- [x] Airplane mode / no connection → clear "no connection" error, not a generic crash — verified 2026-08-31 on the emulator (wifi+data disabled via `adb shell svc wifi/data disable`): "Couldn't reach the server. Check your internet connection and try again." with a Retry button, no crash
- [x] Weak/interrupted connection mid-upload → retry path works — verified 2026-08-31: after the offline error above, re-enabled connectivity and tapped Retry — completed the full flow through to a saved result
- [x] Two different Supabase test accounts → each only sees their own patients/history (RLS actually enforced, not just app-layer filtering) — **rigorously verified 2026-08-31**, both through the app UI and via direct PostgREST calls bypassing the app entirely: signed in as each user's own JWT and confirmed (a) each account's patient list only shows their own data, (b) User B directly requesting User A's patient by ID gets `[]`, (c) User B querying User A's screenings by `patient_id` gets `[]`, (d) User B attempting to UPDATE User A's patient (`name: "HACKED"`) affects 0 rows and User A's data is confirmed unchanged afterward. Second test account (`rlstest01@example.com` / `TestPass123`, patient "RLS") kept as permanent test infrastructure — see HANDOFF.md §10.
- [ ] Supabase project cold-restart-after-pause behavior verified at least once before the demo — not applicable to check right now (project has been continuously active all session, nowhere near the 7-day idle pause threshold); revisit close to the demo date if there's been a gap in usage
- [x] Language toggle switches the entire app (including auth/patient/history screens, not just the old screening flow) to Urdu with correct RTL — verified 2026-08-31 on the emulator across all 7 screens
- [x] Tested on a real Android phone over real mobile data, not just Wi-Fi/emulator — verified 2026-09-01 (Realme RMX5303, release APK). See Troubleshooting Notes for a real release-only bug found and fixed along the way (missing `INTERNET` permission).

## Deployment Checklist

- [ ] Backend Docker image builds and runs correctly (`docker build` + `docker run` locally as a final check)
- [x] Backend deployed to Railway, publicly reachable over HTTPS
- [x] `/health` returns `model_loaded: true` on the deployed instance
- [ ] Supabase schema + RLS policies applied on the real project (not just planned)
- [x] Flutter release APK built (`flutter build apk --release`), installs standalone on a phone — verified 2026-09-01 on a real Realme RMX5303 over real mobile data
- [ ] No secrets, no `.venv`, no dataset redistribution committed to the public GitHub repo

## Final Demo Checklist

- [ ] Demo phone charged, APK pre-installed
- [ ] Backend `/health` and Supabase dashboard both checked/warmed 10-15 min before the slot
- [ ] Test patient + at least one prior screening already in history for a clean live demo
- [ ] Sample fundus photos ready (clear referable, clear non-referable, one deliberately bad file for the error-handling beat)
- [ ] Real mobile data available at the venue (not relying on venue Wi-Fi)
- [ ] Pitch rehearsed out loud, timed, at least twice
- [ ] Known limitations ready to state proactively: not clinically validated, not tested on a Pakistani population, MVP-level PII handling only, our own measured accuracy vs. the model author's published number clearly distinguished

## Known Risks

- **Railway is temporary:** the current credit is a $5/30-day trial. Serverless sleep is enabled to conserve it; migrate or secure another free allowance before it expires if the project must stay online.
- **Model pickle-loading is fragile** — requires `fastai<2.8.0` pinned, a Windows-only `pathlib.PosixPath` shim (already isolated to local dev, skipped automatically on Linux), and stub `get_x`/`get_y` functions (already implemented in `backend/app/model.py`, documented there). Don't "clean up" these workarounds without understanding why they exist.
- **Supabase free project auto-pauses after 7 days idle** → check the dashboard periodically during the build; explicit restart-and-verify the morning of the demo.
- **Cold-start latency on first request after idle** (both the model container and Supabase) → warm both before the demo; don't let the first live request during judging eat a 60-90s cold start.
- **This app now genuinely requires internet** — test on real mobile data during the build, not just venue/dev Wi-Fi.

## Troubleshooting Notes

- **Release APK missing `INTERNET` permission (found and fixed 2026-09-01):** During the first-ever real-device release-build test (Realme RMX5303, real mobile LTE data), login failed with a raw, unlocalized `ClientException with SocketException: Failed host lookup: 'cqpoochxfbjflaxzsfce.supabase.co' (OS Error: No address associated with hostname, errno = 7)`. Confirmed it wasn't a network/carrier issue (the phone's own browser reached the same Supabase URL fine over the same mobile connection at the same time) and wasn't a general release-build networking failure (the existing debug APK, installed side by side on the same phone/network, logged in instantly). `aapt dump permissions` on the two APKs showed the debug build declaring `android.permission.INTERNET` and the release build declaring **no permissions at all**. Root cause: Flutter's default project template only places `<uses-permission android:name="android.permission.INTERNET"/>` in `android/app/src/debug/AndroidManifest.xml` (for `flutter run`'s VM service), never in the main manifest — so any release build silently has no network permission unless a developer adds it themselves. This had been invisible until now because every prior test of this app (emulator, real device, both debug APKs) always used a debug build, which always carries that permission regardless of the main manifest. Fixed by adding the permission to `app/android/app/src/main/AndroidManifest.xml` directly. **Do not remove this line** — it looks redundant next to the debug-manifest one but is the one that actually matters for a real release build. After the fix, rebuilt and reverified the full flow (login → patient → screening → Railway inference → result → Supabase save → history refresh) plus the EN/UR toggle, all on the release APK over real mobile data.
- **Stale screening history after a new screening (fixed 2026-08-31):** `PatientDetailScreen._newScreening()` refreshed the list by awaiting `Navigator.push(ScreeningCaptureScreen)`, but `ScreeningCaptureScreen._analyze()` moves to `ResultScreen` via `pushReplacement`, which resolves that awaited push immediately — before the Supabase insert in `ResultScreen.initState()` even runs, not when the user actually taps "Done". The list refreshed too early and never refreshed again, so a freshly-saved screening was invisible until the screen was torn down and rebuilt (e.g. navigating away and back). Fixed by adding a `RouteObserver` (`routeObserver` in `lib/main.dart`, registered in `MaterialApp.navigatorObservers`) and having `PatientDetailScreen` mix in `RouteAware` and reload in `didPopNext()`, which fires reliably whenever this screen becomes visible again regardless of how many pushes/replacements happened above it. See `app/lib/main.dart`, `app/lib/screens/patients/patient_detail_screen.dart`.
- `PermissionError` on Windows when the backend saves a temp file — already fixed in `backend/app/main.py` (uses `delete=False` + manual cleanup instead of `NamedTemporaryFile(delete=True)`, which holds an exclusive lock on Windows).
- `NotImplementedError: cannot instantiate 'PosixPath'` when loading the model on Windows — expected on a Windows dev machine, already handled by the shim in `backend/app/model.py`; will not occur in the Linux Docker container.
- `AttributeError: ... 'get_x' on <module '__main__'>` when loading the model — expected, already handled by the stub functions in `backend/app/model.py`.
- `ModuleNotFoundError: No module named 'toml'` — `toml` is a required transitive dependency of `from_pretrained_fastai`'s version check; already in `backend/requirements.txt`.
- CORS — not expected to be a real issue for the mobile app (no browser involved), currently wide open during development; see Optional Features for tightening it later.

## Definition of Done

- A release APK installs on a real Android phone and completes the full flow — login → add/select patient → capture photo → real backend inference → correct result — over real mobile data.
- The FastAPI backend is live at a public HTTPS URL, runs the pretrained model (not a mock), and returns validated, honestly-labeled results.
- Patient records and screening history persist in Supabase, correctly isolated per authenticated user.
- English and Urdu both work correctly, including RTL layout, across the full app.
- `docs/EVALUATION_RESULTS.md` contains our own independently-measured numbers, clearly distinguished from the model author's self-reported numbers.
- `docs/DATASET.md`/`docs/ML_PLAN.md` accurately describe the pretrained model's real provenance and license.
- No secrets, no redistributed dataset images, and no leftover on-device-inference code remain in the repository.
- The demo has been rehearsed at least twice, with both the backend and Supabase confirmed warm beforehand.
