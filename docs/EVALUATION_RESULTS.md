# Evaluation Results — BasirahAI

> **Rule for this document: every number below must be either (a) a real, measured result from actually running our deployed pipeline, or (b) explicitly labeled as the model author's self-reported number, never presented as our own. Never fill in a plausible-looking number you didn't actually measure or verify the source of.**

## Two distinct kinds of numbers in this document — do not blend them

1. **The model author's self-reported metrics** (from the [jdelgado2002/diabetic_retinopathy_detection](https://huggingface.co/jdelgado2002/diabetic_retinopathy_detection) model card): validation accuracy 0.840, APTOS private leaderboard score 0.869. We did not measure these ourselves and cannot vouch for the methodology behind them.
2. **Our own independently-measured numbers** (below) — from running real sample images through our actual deployed `/screen` endpoint and scoring the results ourselves.

Both belong in the demo and docs, **clearly labeled which is which** (see `docs/ML_PLAN.md`, `dev/plan.md`'s demo honesty-close talking point).

## Our independent evaluation (Day 2)

- Date: 2026-08-31
- Backend URL/host used for this run: Railway — `https://basirahai-api-production.up.railway.app` (see `dev/plan.md` §8 for hosting details)
- Sample source: APTOS 2019 (Kaggle), `train.csv` + `train_images/` — see `docs/DATASET.md` and important caveat below
- Sample size: 201 images, stratified proportionally to the real 5-class grade distribution across the full 3,662-image training set (seed=42; see `backend/eval_data/select_sample.py`)
- Binary label ground truth used for scoring: grades 0-1 → Non-Referable, 2-4 → Referable (same convention the model uses)

### ⚠️ Important caveat — read before quoting these numbers anywhere

**This sample is drawn from `train.csv`, which is very likely the same labeled data the model author trained on — not a genuinely held-out test set.** The APTOS 2019 Kaggle competition only publishes ground-truth labels for its `train` split; `test.csv`/`test_images/` (the competition's actual held-out evaluation set) has no public labels, so there was no way to build our sample from data the model provably never saw. The evidence supports this: predicted confidence was **≥0.9 for 198/201 images and exactly 1.0 (median) across the sample** — a pattern much more consistent with a model recalling data it trained on than with genuine generalization confidence. This is almost certainly why our measured accuracy (98.5%) comes in well above the model author's own self-reported validation accuracy (0.840, from a validation split they presumably did hold out).

**Do not present these numbers as "our accuracy beats the author's."** State plainly in the demo that this run is a sanity check of the deployed pipeline's mechanics (upload → validation → inference → thresholding → response), not an unbiased accuracy measurement, and that it likely overlaps with the model's own training data. A truly independent accuracy measurement is not possible without either the original held-out labels (not public) or a new, separately-labeled fundus image set (out of scope for this hackathon).

### Headline metrics (our own measurement — see caveat above)

| Metric | Value |
|---|---|
| Sensitivity (recall) for "Referable" | 0.9878 |
| Specificity | 0.9832 |
| Precision | 0.9759 |
| F1 | 0.9818 |
| Accuracy | 0.9851 (report last — not the headline number for a screening tool; also the number most inflated by the training-overlap caveat above) |

### Confusion matrix

```
                     Predicted: Non-Referable   Predicted: Referable
Actual: Non-Referable        117                        2
Actual: Referable              1                        81
```

(117 TN, 2 FP, 1 FN, 81 TP; n=201, 0 request errors)

### Low-confidence cutoff impact

- 0 of 201 screenings fell into the "low-confidence / borderline" bucket at the chosen 0.6 cutoff (`docs/ML_PLAN.md`) — every prediction in this sample scored ≥0.78 confidence, with the vast majority at or near 1.0.
- **This sample cannot meaningfully validate or tune the low-confidence cutoff** — the near-universal high confidence is itself a symptom of the training-overlap caveat above (a model recalling training data is confident almost everywhere, borderline cases included). Tuning the cutoff properly would need genuinely novel images the model hasn't seen, which this sample doesn't provide.

## What these numbers do — and do not — mean

- Our own numbers come from a small sanity-check sample run through the live deployed backend — not a rigorous held-out clinical validation study.
- Neither our numbers nor the model author's numbers were measured on a Pakistani population.
- **Never state a number in the app UI, demo slides, or spoken pitch that isn't recorded here, and always say clearly whether a quoted number is ours or the model author's.**

## Fill in as you go

- [x] All fields above filled in from a real Day 2 run against the live deployed endpoint (2026-08-31, 201/201 images scored, 0 errors — see `backend/eval_data/run_evaluation.py` and its `metrics_summary.json`/`raw_results.json` output, not committed to the repo)
- [x] Confusion matrix filled in
- [ ] Low-confidence cutoff **not** finalized from this data — see caveat above; this sample can't validate it. Still needs either a genuinely novel image set, or an explicit decision to leave the 0.6 placeholder as-is and disclose that in the demo.
- [x] Reviewed for honesty before the final demo — no number here that wasn't actually measured, and the author-vs-ours distinction is unambiguous throughout. **The training-data-overlap caveat above is the single most important thing to say correctly in the demo — do not let the 98.5% number stand alone without it.**
