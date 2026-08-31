# Dataset — BasirahAI

> **We do not train on any dataset.** This document previously described a training-dataset plan (APTOS 2019, self-trained MobileNetV2). That pipeline no longer exists — see `plan.md`'s header note. This document now covers two much narrower things: (1) the dataset the *pretrained model we integrated* was trained on, as documented by its author, and (2) the small sample of images we ourselves pull down for our own independent sanity-check evaluation (Day 2) — not training data.

## The pretrained model's training data (per its author — not verified by us)

Our chosen model, [jdelgado2002/diabetic_retinopathy_detection](https://huggingface.co/jdelgado2002/diabetic_retinopathy_detection), states it was trained on **APTOS 2019 Blindness Detection** (Aravind Eye Hospital, via Kaggle):

- ~3,662 retinal fundus images, 5-class DR severity grade (0-4).
- Kaggle competition license — "Competition Use and Non-Commercial & Academic Research," not CC0, redistribution not permitted.
- No explicit patient-ID field; left/right eyes of the same patient may appear unflagged (a documented limitation of this data source generally, inherited here — we cannot independently verify how the model author split their own train/val/test sets).
- Single institution (India) — **the model has not been validated on a Pakistani population.** State this plainly in the app and demo, not just in this doc.

**We take this provenance claim at face value from the model card — we did not re-verify the author's actual training process, and neither should the app's copy imply more certainty about it than that.**

## Our own evaluation sample (Day 2 — independent sanity check, not training)

To get *our own* measured numbers (rather than relying solely on the author's self-reported metric — see `docs/EVALUATION_RESULTS.md`), we pull a small sample of publicly available APTOS images through the **live deployed `/screen` endpoint** and score the results ourselves:

- Source: same APTOS 2019 Kaggle competition (requires accepting the competition rules on Kaggle before downloading, same as before).
- Sample size: ~150-300 images — enough for a real confusion matrix, not a full retraining/validation split.
- Purpose: an honest, independently-measured sanity check of our deployed pipeline's behavior — **not** a claim of statistically rigorous validation.
- These images are used transiently for scoring and are **not committed to the repository** (same redistribution restriction as before — `.gitignore` covers this).

## What this project does NOT do

- Does not train, fine-tune, or export any model.
- Does not construct or claim a novel Pakistani clinical dataset.
- Does not claim our sanity-check sample size or methodology constitutes clinical validation.

## Fill in as you go

- [x] Day 2 evaluation sample size actually used, and confusion matrix — 201 images, recorded in `docs/EVALUATION_RESULTS.md` (2026-08-31). **Note:** the sample was necessarily drawn from `train.csv` (the competition's only publicly labeled split — `test.csv` has no public labels), which is very likely the same data the model author trained on. See the caveat in `docs/EVALUATION_RESULTS.md` before quoting the resulting numbers anywhere.
- [x] Confirmation the Kaggle competition rules were (re-)accepted before this sample was downloaded — confirmed via the Kaggle API (`userHasEntered: True` for the account used)
