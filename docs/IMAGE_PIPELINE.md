# Image Handling — BasirahAI

> **This document previously specified a Python/Dart preprocessing-parity spec** (matching pixel normalization between a training pipeline and an on-device model). That entire risk class no longer exists — there is now exactly one place inference happens (the backend), and the pretrained model's own exported `Learner` handles its internal preprocessing (resize/normalization) automatically inside `learner.predict()` (see `docs/ML_PLAN.md`). This document now covers the much narrower, real remaining concern: **validating an uploaded image before it reaches the model.**

## Backend-side validation (`backend/app/main.py`, `POST /screen`)

Implemented and tested (`fastapi.testclient.TestClient`, real requests):

1. **Empty file** → `400`, `"Uploaded file is empty."`
2. **Oversized file** (> 10 MB) → `413`, `"Image is too large (max 10 MB)."`
3. **Not a decodable image** (`PIL.Image.open(...).verify()` fails) → `400`, `"This doesn't look like a valid image file."`
4. **Unreadable/corrupt beyond that** → `400`, `"Could not read this image file."`
5. **Implausibly tiny image** (< 64px in either dimension) → `400`, `"Image resolution is too small to analyze. Please retake the photo."`
6. **Implausibly large image** (> `MAX_IMAGE_PIXELS`, default 100 megapixels, env-overridable) → `400`. A decompression-bomb guard: checked against the file's *declared* dimensions before `verify()`/decode ever touches pixel data, so a crafted bomb file doesn't get to consume CPU/memory before being rejected. 100MP sits well above any realistic phone-camera photo (even a 108MP sensor) but far below what a crafted bomb typically claims.
7. **Suitability heuristics** (`backend/app/image_checks.py`, added 2026-09-02): after the checks above pass, a few cheap, Pillow/numpy-only heuristics catch input the model shouldn't be asked to score — extreme aspect ratio, near-black or blown-out exposure, and severe blur (Laplacian variance). **These never prove an image IS a retinal fundus photo, clinically adequate, or disease-free** — they're a coarse "obviously unsuitable" filter only, deliberately tuned conservative (false-rejecting a genuine photo is the failure mode to avoid). A separate, optional circular-fundus-field heuristic exists but defaults **off** (`ENABLE_FUNDUS_SHAPE_CHECK`) because it's the least reliable of the group. Each rejection returns `400` with a structured `detail: {"code": "...", "message": "..."}` (codes: `bad_aspect_ratio`, `too_dark`, `too_bright`, `too_blurry`, `not_fundus_like`) instead of the plain-string `detail` the older checks use — the Flutter client maps the `code` to its own localized string (`ScreeningCaptureScreen._imageIssueMessage`, EN/UR in the ARB files), falling back to `message`/a generic string for a code it doesn't recognize (forward-compatible with a backend-only update).
8. Valid images are converted to RGB and saved to a temp JPEG before being handed to `model.predict()` — this also normalizes away format quirks (e.g. images with an alpha channel, unusual color modes).

Each rejection returns a specific, Flutter-displayable `detail` message — the Flutter app should surface these directly rather than a generic "something went wrong."

**Concurrency:** `/screen` also bounds how many requests run the CPU-heavy decode+inference step at once (`MAX_CONCURRENT_INFERENCE`, default 1 — matched to Railway's single shared vCPU). A request arriving while at capacity gets an immediate `503` rather than queueing, so a burst of uploads can't oversubscribe the container's limited RAM. Cheap validation-only rejections (empty/oversized/corrupt/unsuitable) never need a slot.

## Client-side pre-check (Flutter, optional — Should-Have, not Must-Have)

The original on-device-architecture plan had a Dart blur/brightness heuristic quality gate. In the new architecture this is **no longer required** (the backend validates independently either way), but it's still worth reusing if there's time: catching an obviously bad photo *before* spending an upload + inference round-trip is a nicer user experience, especially on a slow connection. See `dev/plan.md`'s Optional Features list. If implemented, port the blur (edge-difference heuristic) and brightness checks from the earlier handbook material — the logic itself is unaffected by the architecture change, only its role changed (a UX nicety, not a safety-critical gate, since the backend is now the real validation authority).

## What is explicitly NOT re-implemented from the old plan

- No circular fundus crop, no CLAHE/illumination correction — this was already dropped in the earlier on-device plan too, and remains irrelevant now that the model's own exported preprocessing handles normalization internally.
- No manual pixel-level resize/normalization code anywhere in this project — there is nothing to keep in sync between two environments anymore.

## Fill in as you go

- [ ] Confirmed the 10 MB / 64px thresholds are reasonable against real phone camera output (typical modern phone photos are well under 10MB unless at very high resolution — verify once real device testing starts, Day 4+)
- [ ] Noted whether the optional client-side pre-check was implemented, and its final thresholds if so
