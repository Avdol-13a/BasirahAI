# BasirahAI — Handoff Document

_Last updated: 2026-08-31. Written to let a fresh conversation (or a new developer) resume this project with zero prior context. Read this before touching anything._

**Read `plan.md` alongside this file** — `plan.md` is the living day-to-day checklist; this document is the deeper "why and how we got here" reference. If the two ever disagree on current status, trust `plan.md` (it's updated more frequently) but treat this file as the source of truth for architecture rationale, credentials, and gotchas.

---

## 1. Project Identity

- **Name:** BasirahAI — AI-assisted diabetic retinopathy (DR) screening support app for Pakistan.
- **Event:** Alibaba Cloud AI Hackathon Pakistan 2026 (Bano Qabil × Alibaba Cloud). Build phase closes **2026-09-04**.
- **Team:** 3rd-semester CS students. Self-funded/self-hosted — the hackathon organizers gave this team **no Alibaba Cloud credits and no Qoder Enterprise**, only a Qoder Teams seat (2310 credits), which the team **deliberately chose not to use** (not required for judging; switching coding agents mid-build risked losing continuity — see §9).
- **User's real email:** avdol764@gmail.com (also used as their live Supabase test account — see §5).
- **Budget reality:** the team has **no money to spend**. Every infrastructure decision in this project is filtered through "does this cost real money or require a card that could be charged." This shaped the entire hosting search (§4, §8).

## 2. How We Got Here (Architecture History)

The project went through **two distinct architectures**. Only the second one is current.

1. **Original plan (now superseded, kept only for historical reference):** an offline-first Flutter app running a self-trained MobileNetV2 model on-device via TFLite. No backend, no accounts, no patient records. Fully documented in `docs/BASIRAH_HANDBOOK.md` and `docs/Basirah_Beginner_Handbook.pdf` — **these two files describe the OLD architecture and should not be treated as current.** They're left in the repo as reference material only (some pieces, like the Urdu/RTL setup approach and the binary Refer/Non-Referable clinical framing, are still reused).
2. **Current architecture (what's actually being built):** the hackathon re-scoped the submission to require cloud inference, accounts, patient records (incl. optional CNIC), and use of an *existing* pretrained model rather than training one. This is what §3 onward describes.

**Do not reintroduce on-device inference, TFLite, or a self-training pipeline.** That was explicitly ruled out by the team's actual hackathon submission.

## 3. Current Architecture

```
┌─────────────────────────────┐
│        Flutter App           │
│  (Android primary target)    │
│                               │
│  Auth / Patient CRUD / History│──── direct SDK calls ────▶  Supabase
│  (supabase_flutter package)   │                              (Postgres + Auth,
│                               │                               free tier)
│  Image capture/upload,        │
│  screening flow               │──── HTTPS multipart ─────▶  FastAPI backend
│                               │      POST /screen                │
└───────────────────────────────┘                                 ▼
                                                          Pretrained DR model
                                                          (loaded once at startup)
                                                                    │
                                                                    ▼
                                                  { referable: bool, confidence: float,
                                                    raw_grade: 0-4, raw_grade_label: str,
                                                    class_probabilities: [float x5] }
                                                                    │
                                              Flutter receives result ─▶ writes screening
                                              record to Supabase directly (patient_id,
                                              result, confidence, timestamp)
```

**Key design decision:** the FastAPI backend does **one job** — validate an uploaded image and return a screening result. It is stateless and holds no database of its own. Auth, patient records, and screening history all go through **Supabase directly from Flutter**, not through the backend. This was a deliberate simplification (§9) to minimize custom backend code for a small team on a tight deadline.

- **Mobile app:** Flutter (Dart), Android-first. No iOS work attempted.
- **Backend:** FastAPI (Python), one real endpoint (`POST /screen`) + `GET /health`, Dockerized.
- **Model:** pretrained Hugging Face checkpoint (`jdelgado2002/diabetic_retinopathy_detection`), loaded into backend memory once at container startup — never reloaded per-request, never trained/fine-tuned by this team.
- **Data:** Supabase — Postgres (`patients`, `screenings` tables) + Auth (email/password). No Storage bucket in use (raw images are never persisted — see §9).
- **Hosting:** **Railway trial** — live at `https://basirahai-api-production.up.railway.app`; see §8.

## 4. Repository Structure (`D:\Basirah`)

```
D:\Basirah\
├── plan.md                          ← living checklist, updated most frequently
├── HANDOFF.md                       ← this file
├── .gitignore
├── docs/
│   ├── BASIRAH_HANDBOOK.md          ← STALE — old on-device architecture, historical only
│   ├── Basirah_Beginner_Handbook.pdf← STALE — PDF of the above
│   ├── DATASET.md                   ← current — pretrained model's data provenance (not our training data)
│   ├── ML_PLAN.md                   ← current — model choice, loading quirks, confidence derivation
│   ├── EVALUATION_RESULTS.md        ← current — TEMPLATE, real numbers not filled in yet (blocked on deployed backend)
│   ├── IMAGE_PIPELINE.md            ← current — backend-side image validation spec
│   └── MEDICAL_SAFETY.md            ← current — EN/UR safety copy, confidence-display rule (updated from old plan)
├── backend/                          ← FastAPI inference service — BUILT, TESTED, DEPLOYED TO RAILWAY
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                  ← /health, /screen endpoints, image validation
│   │   └── model.py                 ← loads pretrained model, runs predict(), documents 4 real loading fixes
│   ├── Dockerfile                   ← python:3.11-slim, listens on port 7860
│   ├── docker-compose.yml           ← backend + Caddy (auto-HTTPS reverse proxy)
│   ├── Caddyfile                    ← PLACEHOLDER domain, needs real Azure DNS label once VM exists
│   ├── requirements.txt             ← fastai<2.8.0 PINNED — see §7 for why, do not "clean up" this pin
│   ├── README.md                    ← full Azure VM deployment walkthrough, step by step
│   └── .venv/                       ← local Python venv (gitignored, Windows-specific paths)
├── supabase/
│   └── schema.sql                   ← patients + screenings tables, RLS policies, GRANT statements (bug-fixed, see §7)
└── app/                              ← Flutter project — BUILT, `flutter analyze` clean, APK builds successfully
    ├── assets/fonts/                 ← Lora + Manrope variable fonts (SIL OFL), bundled as static assets — see §7 for why not the google_fonts package
    ├── l10n.yaml                     ← ARB-based localization config (arb-dir, output-class AppLocalizations, nullable-getter: false)
    ├── lib/
    │   ├── main.dart                 ← Supabase.initialize, MaterialApp (locale state + BasirahApp.setLocale), AuthGate routing
    │   ├── config/
    │   │   └── env.dart              ← dart-define based config (no hardcoded secrets)
    │   ├── theme/
    │   │   └── app_theme.dart        ← "Warm Earth & Trust" design tokens (AppColors, AppTheme, AccentButton) — source of truth for all screen styling, see §9
    │   ├── l10n/
    │   │   ├── app_en.arb            ← English strings (source of truth for keys)
    │   │   ├── app_ur.arb            ← Urdu translations
    │   │   └── app_localizations*.dart ← GENERATED by `flutter gen-l10n` (gitignored, regenerated at build time — don't hand-edit, don't worry if missing before a build)
    │   ├── widgets/
    │   │   └── language_toggle_button.dart ← app-wide EN/UR toggle (Login + Patients screens), calls BasirahApp.setLocale
    │   ├── utils/
    │   │   └── gender_label.dart     ← maps stored English gender values ('Female'/'Male'/'Other') to localized display labels
    │   ├── models/
    │   │   ├── patient.dart
    │   │   └── result_category.dart  ← low-confidence cutoff logic (0.6 placeholder — needs tuning)
    │   ├── services/
    │   │   └── inference_service.dart← Dio client for POST /screen; throws InferenceException(InferenceErrorCode, {detail}) — the UI layer localizes the message, since this service has no BuildContext (see §7)
    │   └── screens/
    │       ├── auth/
    │       │   ├── auth_gate.dart    ← StreamBuilder on Supabase auth state
    │       │   ├── login_screen.dart
    │       │   └── signup_screen.dart
    │       ├── patients/
    │       │   ├── patient_list_screen.dart  ← has a `print()` in its catch block (intentional debug aid, see §7)
    │       │   ├── patient_form_screen.dart  ← name, DOB, gender, CNIC (optional), phone (optional)
    │       │   └── patient_detail_screen.dart← shows patient info + screening history + "New Screening" button; screening-history subtitle wraps its timestamp in U+200E LRM marks — see §7, don't remove
    │       └── screening/
    │           ├── screening_capture_screen.dart ← camera/gallery pick, dio upload w/ progress
    │           └── result_screen.dart              ← safety-messaged result, saves to Supabase
    ├── android/
    │   └── gradle.properties         ← `kotlin.incremental=false` — fixes a real Windows build bug, see §7
    ├── test/widget_test.dart
    └── pubspec.yaml                  ← dio, supabase_flutter, image_picker, image, flutter_localizations, intl
```

## 5. Environment / Configuration (Local Dev Machine — Windows)

This machine already has everything installed and working as of this handoff:

- **Flutter SDK 3.47.2** at `D:\flutter`, added to the Windows user `PATH`.
- **Android SDK** at `D:\Android` (platform-tools, platforms 35 & 36, build-tools, cmdline-tools, emulator). `ANDROID_HOME` and `ANDROID_SDK_ROOT` set as persistent user env vars, both pointing to `D:/Android`.
- **Android emulator AVD** named `basirah_test` (Pixel 6 profile, Android 15 / API 35, `google_apis` x86_64). **Does not auto-start** — must be launched manually each session (see §10 for the exact command; it does not persist across environment/session restarts).
- **Java 25** (already on system PATH via `C:\Program Files\Common Files\Oracle\Java\javapath\java.exe`) — works fine for the Android SDK tooling despite being newer than typically expected; no action needed.
- **Python 3.11.9**, with a `backend/.venv` containing: `fastai<2.8.0` (pinned!), `huggingface_hub`, `fastapi[standard]`, `python-multipart`, `pillow`, `uvicorn[standard]`, `toml`. (`psutil` and `torchvision` were also installed for one-off memory measurements during debugging — harmless to leave, not required for the app to run, safe to remove from the venv if you want it lean, they are **not** in `requirements.txt`.)
- **No `.env` files needed anywhere.** The backend has zero runtime secrets (model loads from the public Hugging Face Hub). The Flutter app takes its Supabase config via `--dart-define` flags, not a committed file (see §10 for the exact values currently in use).
- **Windows Developer Mode was flagged as possibly required** by an early `flutter pub add` warning about symlinks, but this turned out to be a red herring — the real blocker was a Kotlin incremental-compiler bug (§7), and once that was fixed, builds succeeded **without** enabling Developer Mode. No action needed here unless a new, different symlink-related error appears.

## 6. Verified Functionality (Real, Tested — Not Assumed)

Everything below was actually run and observed working, not just written and assumed correct:

1. **Pretrained model loads and runs correctly.** `from_pretrained_fastai('jdelgado2002/diabetic_retinopathy_detection')` loads successfully (after the 3 fixes in §7); `learner.predict()` returns a valid 5-class softmax distribution summing to 1.0, vocab confirmed as `[0, 1, 2, 3, 4]` matching APTOS grade scale.
2. **Real memory footprint measured directly** (via `psutil`, not estimated): **~536–550MB RSS** with the model loaded and one prediction run. This is real data, not a guess, and it's what ruled out Render's free tier (512MB limit) as a hosting option. Also measured: bare `torchvision.models.resnet50()` with no fastai overhead = **~378MB** — meaning roughly 150–170MB of the footprint is fastai/fastcore machinery specifically, not the model itself. This is a known, unexploited optimization path (see §11).
3. **FastAPI backend tested via `TestClient`** (real requests, not mocks): `/health` returns `{"status": "ok", "model_loaded": true}`; `/screen` correctly returns a real inference result for a valid image, and correctly rejects empty files (400), non-image files (400), and oversized files (413) with specific, Flutter-displayable error messages.
4. **Flutter app builds and runs correctly**: `flutter analyze` is clean, the widget test passes, and a debug APK builds successfully end-to-end (confirms the whole Android toolchain + all plugins compile together, not just that the code looks right on paper).
5. **Full live auth + patient flow tested on the Android emulator against the real, live Supabase project** (not a mock, not localhost):
   - Sign-up with the real account **avdol764@gmail.com** — works.
   - Login — works.
   - Patient creation (`INSERT` into `patients`) — works, verified visually (a "Test Patient" row appeared in the list after saving).
   - Patient list loading (`SELECT` from `patients`) — works, **after** fixing the GRANT bug in §7.
   - Row-Level Security is in place per `schema.sql` (scoped by `owner_user_id = auth.uid()`), though **cross-user isolation with two separate accounts has not yet been empirically tested** — the policy logic is correct by inspection but hasn't been proven with two real accounts side by side.

## 7. Known Bugs Found and Fixed

All of these are real bugs that were actually hit during testing, not hypothetical — future-you should not "clean up" the fixes without understanding why they're there.

| Bug | Symptom | Fix | Where |
|---|---|---|---|
| Missing `toml` dependency | `ImportError: ... require the toml module` when loading the model | `pip install toml`, added to `requirements.txt` | `backend/requirements.txt` |
| `fastai>=2.8.0` incompatible with this specific model's pickle | `RuntimeError: ... fastcore.dispatch and/or fastcore.transform which are deprecated in fastai>=2.8.0` | Pinned `fastai<2.8.0` (tested working: 2.7.19) | `backend/requirements.txt` |
| Windows-only: pickled `PosixPath` objects | `NotImplementedError: cannot instantiate 'PosixPath' on your system` (only on Windows dev machines; the model was exported on Linux/Mac) | `pathlib.PosixPath = pathlib.WindowsPath`, guarded by `if os.name == "nt"` — **does not run in the Linux Docker container** | `backend/app/model.py`, `_apply_windows_pickle_shim()` |
| Pickled `Learner` references undeclared `get_x`/`get_y` functions | `AttributeError: Custom classes or functions exported with your Learner not available in namespace... Can't get attribute 'get_x' on <module '__main__'>` | Register harmless no-op stub functions under those names in `__main__` before loading — only needs to satisfy the pickle loader, never actually invoked during single-image `predict()` | `backend/app/model.py`, `_register_pickle_stubs()` |
| Windows temp-file `PermissionError` | `PermissionError: [Errno 13] Permission denied` when saving an uploaded image to a temp file for inference | `NamedTemporaryFile(delete=True)` holds an exclusive lock on Windows that a second `open()` can't share. Switched to `delete=False` + manual `os.unlink()` in a `finally` block — works on both Windows and the Linux prod container | `backend/app/main.py`, `/screen` endpoint |
| Windows-only Kotlin incremental-compiler bug | `Could not close incremental caches in ...\compileDebugKotlin\...` — broke Android builds for `image_picker_android`, `shared_preferences_android`, etc. Reproducible, not transient (confirmed by hitting it twice with different plugins) | `kotlin.incremental=false` added to `android/gradle.properties` | `app/android/gradle.properties` |
| `schema.sql` missing table-level GRANTs | Every Supabase query failed with `PostgrestException(message: permission denied for table patients, code: 42501)` — **RLS policies alone are not sufficient**; the `authenticated` role also needs base `GRANT SELECT/INSERT/UPDATE/DELETE` privileges on the table | Added explicit `grant select, insert, update, delete on patients/screenings to authenticated;` to `schema.sql`. **This must be (and has been) run directly against the live Supabase project via the SQL Editor** — updating the file alone doesn't retroactively apply to an already-created project; re-run the grants (or the whole file) if a new/different Supabase project is ever used. Also required `notify pgrst, 'reload schema';` to force PostgREST to pick up the change immediately | `supabase/schema.sql` (fixed in file **and** already applied live) |
| `MEDICAL_SAFETY.md` internal contradiction | Old rule said "never show confidence in the UI," but the current hackathon scope explicitly requires showing a confidence score | Rewrote the rule: confidence **is** shown on the result screen, framed as "how confident this specific screening result is," never conflated with overall model accuracy | `docs/MEDICAL_SAFETY.md` |
| Minor `flutter analyze` issues | `anonKey` deprecated (use `publishableKey`), an unnecessary double-underscore lint, a stale `test/widget_test.dart` referencing a renamed `MyApp` class | All three fixed; `flutter analyze` currently reports **zero issues** | `app/lib/main.dart`, `app/lib/screens/patients/patient_list_screen.dart`, `app/test/widget_test.dart` |
| Timestamp visually reordered in Urdu | Screening-history subtitle (`patient_detail_screen.dart`) shows "date time · Confidence" — under Urdu/RTL the raw `DateTime.toString()` value (which contains an internal space) got visually reordered by the Unicode bidi algorithm when embedded in the RTL sentence, e.g. showing the time before the date | Wrapped the date/time substring in U+200E LRM (left-to-right mark) characters before interpolating it into the localized string — standard bidi-isolation technique for embedding an LTR run inside RTL text | `app/lib/screens/patients/patient_detail_screen.dart` |
| `Icon.matchTextDirection` doesn't exist | Assumed `Icon(..., matchTextDirection: true)` would auto-mirror directional icons (chevrons, logout) for RTL, matching `Image`'s real parameter of the same name — `flutter analyze` caught it immediately (undefined named parameter) | Used `Transform.flip(flipX: Directionality.of(context) == TextDirection.rtl, child: Icon(...))` instead | `app/lib/screens/patients/patient_list_screen.dart` |
| `google_fonts` package requires Windows Developer Mode | `flutter pub get` succeeded but pulled in `path_provider`/`jni_flutter`/`hooks`/`code_assets` (native-asset build hooks) that then fail with "Building with plugins requires symlink support / Please enable Developer Mode" | Dropped `google_fonts`; bundled Lora + Manrope as static `.ttf` assets instead (`app/assets/fonts/`, registered in `pubspec.yaml`'s `flutter: fonts:` section) — works offline too, no runtime CDN fetch | `app/pubspec.yaml`, `app/assets/fonts/` |
| Screening history didn't refresh after a new screening | Found 2026-08-31 during the first full end-to-end test against Railway. `PatientDetailScreen._newScreening()` refreshed via `await Navigator.push(ScreeningCaptureScreen)`, but `ScreeningCaptureScreen._analyze()` moves to `ResultScreen` with `pushReplacement`, which resolves that await immediately — before `ResultScreen`'s Supabase insert even runs, not when the user taps "Done". Confirmed via direct REST query against Supabase that the insert itself always succeeded; only the UI refresh was stale. | Added a `RouteObserver` (`routeObserver`, `app/lib/main.dart`, registered in `MaterialApp.navigatorObservers`); `PatientDetailScreen` now mixes in `RouteAware` and reloads in `didPopNext()`, which fires whenever the screen becomes visible again regardless of intervening pushes/replacements | `app/lib/main.dart`, `app/lib/screens/patients/patient_detail_screen.dart` |

**One intentional non-fix, left in place on purpose:** `patient_list_screen.dart`'s catch block has `print('LOAD PATIENTS ERROR: $e')` before setting the generic user-facing error message. This was added to diagnose the GRANT bug above via `adb logcat` and is being **kept** as a permanent debug aid — real Postgrest/Supabase exceptions are informative and worth seeing in logs during continued development. Not a leftover to be cleaned up.

## 8. Hosting — Railway Live, Azure Still Pending

Azure verification did not clear in time, so it is no longer on the critical path.

- **Live URL:** `https://basirahai-api-production.up.railway.app`
- **Railway project/service:** `gregarious-insight` / `basirahai-api`
- **Plan:** $5 trial credit for 30 days; no card was required. This is temporary, not an indefinite free tier.
- **Runtime:** Docker deployment with serverless sleep enabled, `/health` health check, and a 300-second startup allowance.
- **Verified 2026-08-31:** `/health` returned `model_loaded: true`; a warm `/screen` request completed in ~0.74s. The original build took 83s per inference due to shared-CPU thread oversubscription; limiting PyTorch to one thread fixed it.
- **Memory optimization:** production inference now uses a bare PyTorch ResNet-50 plus replicated fastai transforms. Output parity was verified locally (maximum logit difference `1.907e-06`), and full API RSS after inference measured ~482.7MB. fastai is used only during the Docker build to convert the trusted checkpoint to a plain state dict.

- **Previous dead ends:** Hugging Face compute became paid; no Alibaba credits were supplied; Google Cloud requested a prepayment; Oracle signup failed; and Azure student verification remained pending.
- **Render fallback:** the optimized runtime now fits under its 512MB free-tier ceiling locally, but with little headroom. Railway was chosen first because its trial supplies 1GB RAM and was immediately available.

## 9. Important Decisions Made, With Rationale

Preserve these — they were deliberate, not accidental, and re-litigating them without new information would waste time:

1. **Model choice: `jdelgado2002/diabetic_retinopathy_detection`** over alternatives found during research (Kontawat's ViT model has a blank/undocumented dataset field on its own model card; ArjTheHacker's repo has no stated license and looks abandoned; sakshamkr1's model is CC-BY-NC, non-commercial only). This one has a clear MIT license and clear APTOS 2019 provenance, which matches the project's existing dataset documentation and its "don't fabricate provenance" principle.
2. **Flutter talks to Supabase directly, not through the backend**, for everything except the actual screening inference call. This was a deliberate "minimal moving parts" simplification — the team writes almost no custom backend CRUD/auth code, leaning on Supabase's official SDK and Row-Level Security instead.
3. **No image retention.** Raw uploaded fundus photos are never persisted anywhere — they go to the backend for inference and are discarded after the response returns. Only the numeric result (`referable`, `confidence`, `raw_grade`, `raw_grade_label`, timestamp) is stored in `screenings`. Chosen for privacy and simplicity; a compressed thumbnail is a documented "nice to have," not a requirement.
4. **Binary result derivation**: model grades 0–1 → `referable: false` (Non-Referable); grades 2–4 → `referable: true` (Referable). This is the standard clinical "referable DR" cut point, not invented for this project. `confidence` is the **summed probability mass of the winning binary side**, not just the single top-class probability — chosen because it better represents how sure the binary screening call is.
5. **Low-confidence cutoff = 0.6, currently a placeholder.** Below this, the result screen shows "Result Not Clear" regardless of the raw referable/non-referable call. This needs to be tuned once real evaluation data exists (blocked on the backend being deployed — see §11's next steps).
6. **State management: plain `StatefulWidget`/`setState` everywhere**, no Provider/Riverpod/Bloc. Deliberately kept simple for a small team on a tight deadline with a linear app flow.
7. **CORS is wide open** (`allow_origins=["*"]`) in the backend, by design, for development convenience. Documented as something to tighten before the final demo *if there's time* — explicitly not a priority over getting the core flow working.
8. **Qoder (2310 credits, Teams plan) is deliberately not being used**, even though it was offered. Reasoning discussed directly with the user: it's a separate, standalone coding IDE (not something that can be "connected" to this session), it's not required for hackathon judging, and switching some of the work to it mid-build would mean re-deriving context that this session already has, which is real risk this close to the deadline. If the user ever wants to revisit this, the reasoning is preserved here so it doesn't need to be re-explained.
9. **"Confirm email" is turned OFF** in the live Supabase project's auth settings, for development convenience (avoids Supabase's free-tier email-sending rate limit during iterative testing). This setting lives under **Authentication → Sign In / Providers → "User Signups" section** — notably **not** inside the "Email" provider's own settings panel, which is where one would naturally look first (this caused real confusion during setup, worth remembering). Consider whether to turn this back on before a real/production launch — not a concern for the hackathon demo.

## 10. Exact Values / How to Resume Local Work

**Supabase project (live, real, already has data in it):**
- URL: `https://cqpoochxfbjflaxzsfce.supabase.co`
- Anon key: intentionally omitted from source control; provide it via `--dart-define=SUPABASE_ANON_KEY=...`.
- `schema.sql` has been fully applied to this project already (tables + RLS + grants all live).
- A real test account already exists and has a "Test Patient" record. Its credentials are intentionally omitted from source control; do not delete its data casually.
- A second, likely-orphaned test account may exist: `basirahtest.qa@gmail.com` — created during an earlier test before "Confirm email" was turned off; its confirmation email was never successfully delivered (hit the rate limit). Low priority; safe to ignore or clean up later.

**To run the backend locally** (Windows Git Bash):
```bash
cd D:/Basirah/backend
source .venv/Scripts/activate
uvicorn app.main:app --reload --port 8000
```

**To launch the Android emulator** (does not auto-start, must be run each session):
```bash
export ANDROID_HOME="D:/Android"
export PATH="/d/Android/emulator:/d/Android/platform-tools:$PATH"
"D:/Android/emulator/emulator.exe" -avd basirah_test -no-snapshot -no-boot-anim &
```
Then wait for boot with:
```bash
until adb shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; do sleep 5; done
```

**To build and install the Flutter app with real Supabase config** (replace values if the project ever changes):
```bash
export PATH="/d/flutter/bin:/d/Android/platform-tools:$PATH"
export ANDROID_HOME="D:/Android"
export ANDROID_SDK_ROOT="D:/Android"
cd D:/Basirah/app
flutter build apk --debug \
  --dart-define=SUPABASE_URL=https://cqpoochxfbjflaxzsfce.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-supabase-anon-key>
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.basirahai.basirah_app/com.basirahai.basirah_app.MainActivity
```
The app now defaults `BACKEND_URL` to the live Railway URL. Override it with `--dart-define=BACKEND_URL=http://127.0.0.1:8000` when using `adb reverse` for local backend development.

## 11. Pending Tasks — Exact Next Steps, In Priority Order

1. ~~**Test the full Flutter flow against Railway**~~ — **done 2026-08-31** on the Android emulator: capture → upload → inference → result → Supabase history all verified working, using a synthetic test image (not a real fundus photo — real APTOS images are still needed for #2 below). Found and fixed one real bug along the way (stale screening history list — see §7). Still worth a pass on a **real Android device** before the demo, but the flow itself is confirmed working.
2. ~~**Run the independent sanity-check evaluation**~~ — **done 2026-08-31**: 201 real APTOS images (Kaggle, stratified sample of `train.csv`) run through the live `/screen` endpoint, 0 errors, real numbers recorded in `docs/EVALUATION_RESULTS.md` (sensitivity 0.9878, specificity 0.9832, accuracy 0.9851). **Read the caveat at the top of that section before quoting these anywhere**: the sample almost certainly overlaps with the model's own training data (it had to — `train.csv` is APTOS 2019's only publicly-labeled split), which is why our number comes in above the author's self-reported 0.840. This is a sanity check of the deployed pipeline's mechanics, not an unbiased accuracy measurement.
   - **Still open:** tune the low-confidence cutoff (currently 0.6 placeholder). This evaluation run can't do it — every one of the 201 predictions scored ≥0.78 confidence (median 1.0), which is itself a symptom of the training-overlap issue above, not evidence the cutoff is well-calibrated. Real tuning needs genuinely novel images the model hasn't seen, which wasn't achievable within this hackathon's scope. Options: leave 0.6 as an explicitly-disclosed placeholder for the demo, or make a documented judgment call.
3. ~~**Urdu/RTL localization**~~ — **done 2026-08-31**, across all 7 screens, verified visually on the emulator in both languages. See the repo-structure notes above (`l10n.yaml`, `lib/l10n/`, `lib/widgets/language_toggle_button.dart`) and the Known Bugs table for the two real issues hit and fixed along the way (bidi timestamp reordering, a nonexistent `Icon.matchTextDirection`). The language toggle is in-memory only — it does not persist across app restarts (no `shared_preferences` dependency added, to avoid risking another Windows-Developer-Mode build blocker like `google_fonts` hit). Revisit only if there's time; not required for the demo.
4. **Full manual testing pass** — include bad uploads, network failures, Railway cold start, Supabase pause recovery, and cross-user RLS isolation.
5. **Release APK build + real-device testing over real mobile data.**
6. **Demo rehearsal**, including the documented limitations and a backend warm-up shortly before judging.

**Optimization completed:** production uses a bare `torch.nn.Module`; do not restore runtime fastai unless a validated model change requires it.

## 12. Other Context Worth Knowing

- This session also maintains its own persistent memory (separate from this file) at `C:\Users\user\.claude\projects\D--Basirah\memory\` — specifically `project_basirahai_hosting_saga.md` (the hosting search history, mirrors §8 above) and `feedback_dont_pivot_during_infra_fatigue.md` (a behavioral note: when this user is fatigued from repeated infra dead-ends and says something like "let's just wait," stop proposing alternatives immediately rather than continuing to problem-solve). These auto-load for Claude Code sessions with this user; a human or a different tool resuming this project wouldn't see them, which is part of why this HANDOFF.md exists as a portable, repo-level equivalent.
- The user communicates tersely and gets frustrated by repeated dead ends (evidenced across the hosting search in §8) — when picking this back up, lead with concrete status/next-action, not a long re-explanation of things already settled here.
- **Never fabricate metrics, dataset provenance, or clinical validation claims anywhere in this project** — this is a repeated, explicit instruction from the original hackathon scope and is reflected throughout `docs/EVALUATION_RESULTS.md`, `docs/DATASET.md`, and `docs/MEDICAL_SAFETY.md`. Any future work must keep honoring this.
