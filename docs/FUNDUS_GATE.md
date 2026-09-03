# Fundus Content Pre-Filter — BasirahAI

## The bug

2026-09-03, during the blur-gate recalibration fix (see `docs/IMAGE_PIPELINE.md`), a user reported the app misbehaving again after that fix shipped. Investigation reproduced a real, separate bug: the app's own logo (`app/assets/branding/basirah_logo.png`, not a fundus photo at all) submitted to the live `/screen` endpoint returned a **confident, wrong** result — `referable: false, confidence: 1.0, "No DR"`, zero warnings.

Root cause: the existing image-suitability checks (`backend/app/image_checks.py`) — aspect ratio, exposure, blur — validate image *quality*, never *content*. Nothing in the pipeline ever asked "is this actually a retinal fundus photo?" The one heuristic written for that purpose (`check_fundus_like_structure`, code `not_fundus_like`) has been disabled by default since it was added on 2026-09-02, and even if enabled, it wouldn't have caught the logo — it only rejects images with too little bright coverage (a dark-surround/vignette check), and the logo is 93% bright pixels.

The blur-gate recalibration made this gap somewhat wider (lowering the blur floor let more borderline-soft random photos through that used to be accidentally caught), but the logo itself proves the gap predates that fix — its blur variance (3547) was always far above even the old, stricter threshold. This was a pre-existing structural gap, not something the blur fix introduced from nothing.

## Why a cheap heuristic doesn't work

Before building anything ML-based, a red-channel-dominance heuristic was tried: real fundus photos are dominated by red/orange hues (blood vessels, hemoglobin), so "how red is this image" seemed like a plausible cheap signal. Measured against the real 201-image APTOS evaluation sample, it looked promising — a clean gap between the logo (ratio 0.45) and every real fundus photo (minimum ratio 0.58).

It was rejected anyway, because it was tested against the single most likely accidental input first: common warm-toned real-world objects (skin, wood, brick, fruit). Every one of them scored *higher* red-dominance than the real fundus floor (light skin: 0.70; medium skin: 0.84; wood: 0.79; brick: 1.08; tomato: 3.0). Shipping this would have caught cool-toned junk (logos, icons, screenshots) while waving through the most likely real accidental input — a photo of someone's own hand. A false sense of security is worse than the visible bug, so this approach was abandoned before writing any production code.

## What was built instead

A small binary classifier: a frozen, ImageNet-pretrained **MobileNetV3-Small** backbone (torchvision, ~10MB — the same dependency `backend/app/model.py` already uses) as a feature extractor, plus a small trained logistic head (`Linear(576, 1)`) on top. Only the head is trained; the backbone's ImageNet features are used as-is. Training script: `backend/train_fundus_gate.py`.

### Data

- **Positives** ("is a fundus photo"): the 201 real APTOS images already in `backend/eval_data/images/` — the same real, clinically-labeled sample used for the DR model's own evaluation.
- **Negatives** ("is not a fundus photo"): two deliberately different sources.
  1. **CIFAR-10** (400 sampled images) — real photographs across 10 everyday classes (planes, cars, birds, cats, deer, dogs, frogs, horses, ships, trucks). Fetched via the Kaggle API (`pankrzysiu/cifar10-python`, the standard `cifar-10-python.tar.gz` format) rather than torchvision's own mirror, which measured ~30-40kB/s from this network (170MB would have taken over an hour) — Kaggle delivered the same content (~325MB zip) in ~80 seconds.
  2. **Procedurally generated flat/graphic images** (250 images) — solid backgrounds with random geometric shapes in varied palettes. Added after a first training pass with CIFAR-10 alone.

### First-pass finding (kept here, not hidden)

Training on CIFAR-10 negatives alone produced a classifier with a perfect-looking **1.0 held-out validation accuracy** — and it still failed the one case that mattered: the app's own logo, held out of training entirely, scored **88.8% "fundus."** CIFAR-10's negatives are all busy, continuous-tone natural photos; the model learned to separate "fundus photo" from "photo of an object" without ever learning to reject a flat vector graphic. This is exactly the kind of validation-shaped-hole the project's "never fabricate metrics" principle exists to catch — a clean val-set number that doesn't mean what it looks like it means.

The synthetic flat/graphic negatives were added specifically to close that gap. Retrained, the logo dropped to **56.8%** — better, but still on the wrong side of a naive 0.5 cutoff. This is why the deployed decision threshold (below) is not 0.5.

### Final measured results (`backend/eval_data/fundus_gate_metrics.json`)

- Held-out validation split (40 real fundus + 130 negative, never trained on): **100% accuracy**, 0 false rejects, 0 false accepts.
- Fundus-probability distribution across **all 201** real fundus photos: p0 (minimum) = **0.8575**, p1 = 0.8874, p2 = 0.9157, p5 = 0.9462, median = 0.9904.
- A 9-image independent sanity set (app logo, app icons ×3, UI screenshots ×4 — **none used in training**): highest score among them was the logo at **0.5682**; every other non-fundus image scored below 0.05.

### Deployed thresholds (`backend/app/fundus_gate.py`)

Two-tier, same pattern as the blur gate:

| Range | Behavior | Code |
|---|---|---|
| `probability < 0.7` | **Reject** (400) | `not_fundus_photo` |
| `0.7 ≤ probability < 0.85` | **Warn**, still scored (200 + warning) | `uncertain_fundus_content` |
| `probability ≥ 0.85` | Pass, no warning | — |

`0.7` sits comfortably below every real fundus photo observed (floor 0.8575, margin ~0.16) and above every known non-fundus sanity image (ceiling 0.5682, margin ~0.13). `0.85` sits just below the real observed floor, as a safety margin for genuine photos this specific 201-image sample didn't happen to cover — a warning, not a rejection, so an unusual-but-real fundus photo is never silently blocked.

**Re-validated against all 201 real fundus photos through the actual deployed `check_fundus_content` function: 0 rejected, 0 warned.**

### Memory footprint

Measured directly (`psutil`, real process, not estimated): loading the frozen MobileNetV3-Small backbone + trained head costs **~98MB** RSS on top of an already-loaded torch/torchvision runtime, plus a small transient amount per inference. Combined with the DR model's own measured production footprint (~483MB), the estimated total is **~580-610MB** — comfortably under Railway's ~1GB trial ceiling, with real headroom to spare.

### Build/deploy integration

Same pattern as the DR model (`backend/export_model.py`): the MobileNetV3-Small backbone is downloaded and converted to a plain state dict **at Docker build time** (`backend/export_fundus_backbone.py`), not at container startup — the running container never needs a network call to `download.pytorch.org`. The trained head (`backend/app/fundus_gate_head.pt`, ~2KB) is small enough to commit directly to the repo, unlike the DR model's ~100MB artifact.

## External validation against IDRiD (2026-09-03)

The numbers above all come from data connected to this gate's own training (APTOS positives, CIFAR-10/synthetic negatives). To check for shortcut-learning against the training corpus itself, the same **unmodified, already-deployed** gate (no retraining, no threshold changes) was run against **IDRiD** — a genuinely independent retinal fundus dataset, never used anywhere in training or calibration. Reproducibility script: `backend/eval_data/run_idrid_validation.py` (raw per-image results are gitignored, like the rest of this project's evaluation data — see the root `.gitignore`'s eval-data policy).

**Dataset prep:** IDRiD ships fundus photos under three challenge tasks (Segmentation, Disease Grading, Localization), which turned out to substantially overlap — Disease Grading and Localization are byte-identical (confirmed by MD5), and Segmentation shares a handful of images with both. Deduplicating by content hash across all three: **1113 raw files → 588 unique fundus photographs**. Masks, groundtruth CSVs, and annotation files were excluded — only "Original Images" folders were used.

**Results, all 588 images, thresholds unchanged (reject < 0.70, warn 0.70-0.85, pass ≥ 0.85):**

| Metric | Value |
|---|---|
| Min / Max | 0.8185 / 0.9993 |
| Mean / Median | 0.9901 / 0.9944 |
| p1 / p5 / p10 / p25 | 0.9316 / 0.9685 / 0.9782 / 0.9896 |
| Rejected (< 0.70) | **0 / 588 (0.0%)** |
| Warned (0.70-0.85) | 1 / 588 (0.17%) |
| Passed (≥ 0.85) | 587 / 588 (99.83%) |
| Rejected by the *other* suitability checks (aspect ratio/exposure/blur) | **0 / 588** |

The one warned image (`IDRiD_081.jpg`, training split, score 0.8185) was visually inspected: it has a large, sharply-bordered overexposure/glare artifact covering roughly 40% of the fundus field — a genuine image-quality defect, not a gate malfunction. No image scored below 0.85 for any other reason, so no further inspection was needed.

**IDRiD's observed floor (0.8185) is lower than APTOS's (0.8575)** — expected, and a reassuring sign this check isn't circular (a genuinely different dataset does score somewhat differently). It still sits **0.12 above the reject threshold** and **0.25 above the known non-fundus ceiling (0.5682)**. No evidence of a generalization failure; the 0.70 reject threshold was left unchanged, as instructed for this evaluation pass.

**Caveat:** IDRiD and APTOS are both standard color fundus photography with similar framing conventions, so this is a real external check but not a maximally adversarial one (e.g. a different imaging modality entirely would be a harder test). Worth a stronger stress test later if time allows.

## Honest limitations

This is a real improvement, not a solved problem:

- **Negative training data is necessarily incomplete.** CIFAR-10 and procedural graphics cover two broad categories ("photo of an everyday object," "flat graphic"); they cannot cover every possible non-fundus image a user might submit. An unusual real photo (e.g. an actual close-up of an eye that isn't a fundus view, or another kind of medical image) could still be misclassified as fundus-like.
- **This is a same-day first pass, not a clinically validated detector.** The validation numbers above are real and honestly measured, but the held-out validation set (40 positive / 130 negative) and sanity set (9 images) are both small.
- **This does not replace the existing quality checks** (`docs/IMAGE_PIPELINE.md`) — it runs in addition to them, after aspect ratio/exposure/blur pass, before the DR model runs.
- Should real-world usage surface new false accepts or false rejects, retrain (`backend/train_fundus_gate.py`) with the new cases added to the negative (or positive) set — don't just nudge the threshold without adding real data, or the same shortcut-learning failure mode from the first training pass can recur.
