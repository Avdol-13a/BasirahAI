# Image Handling — BasirahAI

> **This document previously specified a Python/Dart preprocessing-parity spec** (matching pixel normalization between a training pipeline and an on-device model). That entire risk class no longer exists — there is now exactly one place inference happens (the backend), and the pretrained model's own exported `Learner` handles its internal preprocessing (resize/normalization) automatically inside `learner.predict()` (see `docs/ML_PLAN.md`). This document now covers the much narrower, real remaining concern: **validating an uploaded image before it reaches the model.**

## Backend-side validation (`backend/app/main.py`, `POST /screen`)

Implemented and tested (`fastapi.testclient.TestClient`, real requests):

1. **Empty file** → `400`, `"Uploaded file is empty."`
2. **Oversized file** (> 10 MB) → `413`, `"Image is too large (max 10 MB)."`
3. **Not a decodable image** (`PIL.Image.open(...).verify()` fails) → `400`, `"This doesn't look like a valid image file."`
4. **Unreadable/corrupt beyond that** → `400`, `"Could not read this image file."`
5. **Implausibly tiny image** (< 64px in either dimension) → `400`, `"Image resolution is too small to analyze. Please retake the photo."`
6. Valid images are converted to RGB and saved to a temp JPEG before being handed to `model.predict()` — this also normalizes away format quirks (e.g. images with an alpha channel, unusual color modes).

Each rejection returns a specific, Flutter-displayable `detail` message — the Flutter app should surface these directly rather than a generic "something went wrong."

## Client-side pre-check (Flutter, optional — Should-Have, not Must-Have)

The original on-device-architecture plan had a Dart blur/brightness heuristic quality gate. In the new architecture this is **no longer required** (the backend validates independently either way), but it's still worth reusing if there's time: catching an obviously bad photo *before* spending an upload + inference round-trip is a nicer user experience, especially on a slow connection. See `dev/plan.md`'s Optional Features list. If implemented, port the blur (edge-difference heuristic) and brightness checks from the earlier handbook material — the logic itself is unaffected by the architecture change, only its role changed (a UX nicety, not a safety-critical gate, since the backend is now the real validation authority).

## What is explicitly NOT re-implemented from the old plan

- No circular fundus crop, no CLAHE/illumination correction — this was already dropped in the earlier on-device plan too, and remains irrelevant now that the model's own exported preprocessing handles normalization internally.
- No manual pixel-level resize/normalization code anywhere in this project — there is nothing to keep in sync between two environments anymore.

## Fill in as you go

- [ ] Confirmed the 10 MB / 64px thresholds are reasonable against real phone camera output (typical modern phone photos are well under 10MB unless at very high resolution — verify once real device testing starts, Day 4+)
- [ ] Noted whether the optional client-side pre-check was implemented, and its final thresholds if so
