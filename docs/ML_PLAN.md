# ML Plan — BasirahAI

> **We do not train or fine-tune any model.** This document describes how an existing pretrained checkpoint is integrated into the backend, not a training pipeline. If you're looking for training code, there isn't any — that's intentional (see the hackathon scope revision in `dev/plan.md`'s header note).

## Task framing

Binary screening classification: **Referable** (moderate-or-worse diabetic retinopathy) vs. **Non-Referable** (no/mild DR) — the same clinically standard "referable DR" cut point used throughout this project (see `docs/MEDICAL_SAFETY.md`). The underlying model produces a 5-class grade (0-4); the backend collapses it to this binary result plus a confidence score.

## Chosen model

**[jdelgado2002/diabetic_retinopathy_detection](https://huggingface.co/jdelgado2002/diabetic_retinopathy_detection)**

- **Architecture:** ResNet-50, fine-tuned via fastai.
- **License:** MIT (explicit, verified on the model card).
- **Training data (per the model card, not verified by us beyond our own Day 2 sanity check):** APTOS 2019 Blindness Detection (Kaggle) — the same dataset this project already researched in depth.
- **Author-reported metrics:** validation accuracy 0.840, APTOS competition private leaderboard score 0.869. **These are the model author's self-reported numbers — not independently verified by us, and not the same as our own measured numbers in `docs/EVALUATION_RESULTS.md`. Never blend or confuse the two in the app, docs, or demo.**
- **Output:** 5-class softmax over grades 0 (No DR) – 4 (Proliferative DR), vocab confirmed at load time as `[0, 1, 2, 3, 4]`.

### Why this model over the alternatives researched

| Alternative | Why not chosen |
|---|---|
| Kontawat/vit-diabetic-retinopathy-classification (Apache-2.0, ViT) | Simpler to load (plain `transformers`), but its model card's dataset field is blank — undocumented training-data provenance is a worse fit for a project whose explicit principle is "don't fabricate provenance/validation." Kept as the documented fallback if fastai loading becomes unworkable. |
| ArjTheHacker/diabetic-retinopathy-detection | No license stated, unfilled template placeholders on the model card — looks abandoned/incomplete. |
| sakshamkr1/ResNet50-APTOS-DR | CC-BY-NC 4.0 — non-commercial only, a real license restriction we'd rather not build around; non-standard loading code (raw `torch.load()` of a full pickled object). |

## Loading the model — real, verified quirks (not hypothetical)

Implemented in `backend/app/model.py`. Three real issues were hit and fixed while spiking this on 2026-08-28, kept here so nobody "cleans up" the fix without knowing why it's there:

1. **Missing `toml` dependency.** `from_pretrained_fastai`'s version-compatibility check imports `toml`, which isn't pulled in automatically. Added to `requirements.txt`.
2. **`fastai>=2.8.0` breaks unpickling this specific model.** fastai 2.8 moved `Pipeline` out of `fastcore.transform` into a new `fasttransform` package, and this model's `.pkl` was exported against the old layout. **Pinned `fastai<2.8.0`** (tested working: 2.7.19) in `requirements.txt`.
3. **`get_x`/`get_y` name resolution.** The exported `Learner`'s embedded `DataBlock` references custom `get_x`/`get_y` functions by name from the training script's `__main__` module, which we don't have. Registered harmless no-op stubs under those names in `__main__` before loading — this only needs to satisfy the pickle loader; the stubs are never actually invoked during single-image `predict()`.
4. **Windows-only:** the `.pkl` was exported on Linux/Mac and contains pickled `PosixPath` objects, which fail to unpickle natively on Windows. `model.py` aliases `pathlib.PosixPath = pathlib.WindowsPath`, guarded by `if os.name == "nt"` — **this does not run in the production Linux Docker container**, where it's unnecessary.

All four are implemented and verified working locally (model loads, `predict()` returns a valid 5-class probability distribution summing to 1.0).

## Binary referable call and confidence derivation

**Updated 2026-09-02** — `referable` is decided independently from `raw_grade`, not derived from it. The model's raw softmax gives 5 class probabilities; `raw_grade` (the single most likely class) and the binary `referable` call are two separate signals that can disagree:

```
non_referable_probability = probs[0] + probs[1]
referable_probability = probs[2] + probs[3] + probs[4]
referable = referable_probability >= non_referable_probability
confidence = referable_probability if referable else non_referable_probability
raw_grade = argmax(probs)  # informational only, unaffected by the line above
```

**Why aggregate mass instead of "is raw_grade in {2,3,4}":** the earlier implementation derived `referable` from whether the single-class argmax fell on the referable side, which can disagree with which side actually has more aggregate probability mass. Example: `probs = [0.05, 0.30, 0.28, 0.22, 0.15]` — `raw_grade` is 1 ("Mild", the largest single class), but the referable side's summed mass (0.28+0.22+0.15=0.65) exceeds the non-referable side's (0.05+0.30=0.35). Aggregated mass is the more defensible signal for a binary screening call than a single-class plurality vote, so it wins; `raw_grade`/`raw_grade_label` are still reported, but purely as informational detail, not as the source of truth for the referable/non-referable call. See `backend/app/model.py`'s `predict()` and `backend/tests/test_model.py::test_predict_argmax_and_aggregate_disagree` for a worked test case of this disagreement.

An exact tie between the two sides resolves to referable (the `>=`), the more sensitive/conservative choice for a screening tool.

## Low-confidence cutoff

A `confidence` below a chosen cutoff routes to the "low-confidence / borderline" result category (`docs/MEDICAL_SAFETY.md`) instead of a confidently-worded Referable/Non-Referable message.

- **Starting value:** 0.6 (placeholder — not yet tuned against real data).
- **Final value used:** _fill in during Day 2's independent evaluation_, once real sensitivity/specificity numbers are available to judge the tradeoff.

## What we explicitly do NOT do

- Train or fine-tune any model.
- Run inference on the phone.
- Claim clinical validation, regulatory clearance, or a specific accuracy for our own deployed pipeline without measuring it ourselves (see `docs/EVALUATION_RESULTS.md`).
- Present the model author's self-reported metric as our own measured performance.

## Fill in as you go

- [ ] Low-confidence cutoff finalized after Day 2's evaluation
- [ ] Confirmed the same loading approach works inside the actual Linux Docker container (not just local Windows dev)
- [ ] If the Kontawat fallback model was ever used instead, this document and `docs/DATASET.md` updated to reflect its (undocumented) provenance honestly
