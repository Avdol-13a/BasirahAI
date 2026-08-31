# Evaluation Results — BasirahAI

> **Rule for this document: every number below must be either (a) a real, measured result from actually running our deployed pipeline, or (b) explicitly labeled as the model author's self-reported number, never presented as our own. Never fill in a plausible-looking number you didn't actually measure or verify the source of.**

## Two distinct kinds of numbers in this document — do not blend them

1. **The model author's self-reported metrics** (from the [jdelgado2002/diabetic_retinopathy_detection](https://huggingface.co/jdelgado2002/diabetic_retinopathy_detection) model card): validation accuracy 0.840, APTOS private leaderboard score 0.869. We did not measure these ourselves and cannot vouch for the methodology behind them.
2. **Our own independently-measured numbers** (below) — from running real sample images through our actual deployed `/screen` endpoint and scoring the results ourselves.

Both belong in the demo and docs, **clearly labeled which is which** (see `docs/ML_PLAN.md`, `plan.md`'s demo honesty-close talking point).

## Our independent evaluation (Day 2)

- Date: _fill in_
- Backend URL/host used for this run: _fill in (Azure VM — see backend/README.md)_
- Sample source: APTOS 2019 (Kaggle), a small held-out sample — see `docs/DATASET.md`
- Sample size: _fill in_
- Binary label ground truth used for scoring: grades 0-1 → Non-Referable, 2-4 → Referable (same convention the model uses)

### Headline metrics (our own measurement)

| Metric | Value |
|---|---|
| Sensitivity (recall) for "Referable" | _fill in_ |
| Specificity | _fill in_ |
| Precision | _fill in_ |
| F1 | _fill in_ |
| Accuracy | _fill in (report last — not the headline number for a screening tool)_ |

### Confusion matrix

```
                     Predicted: Non-Referable   Predicted: Referable
Actual: Non-Referable        _fill in_                _fill in_
Actual: Referable             _fill in_                _fill in_
```

### Low-confidence cutoff impact

- How many of the sample's screenings fell into the "low-confidence / borderline" bucket at the chosen cutoff (`docs/ML_PLAN.md`)? _fill in_
- Did adjusting the cutoff meaningfully change sensitivity/specificity? _fill in_

## What these numbers do — and do not — mean

- Our own numbers come from a small sanity-check sample run through the live deployed backend — not a rigorous held-out clinical validation study.
- Neither our numbers nor the model author's numbers were measured on a Pakistani population.
- **Never state a number in the app UI, demo slides, or spoken pitch that isn't recorded here, and always say clearly whether a quoted number is ours or the model author's.**

## Fill in as you go

- [ ] All fields above filled in from a real Day 2 run against the live deployed endpoint
- [ ] Confusion matrix filled in
- [ ] Low-confidence cutoff finalized based on this data (recorded back in `docs/ML_PLAN.md` and `docs/MEDICAL_SAFETY.md`)
- [ ] Reviewed for honesty before the final demo — no number here that wasn't actually measured, and the author-vs-ours distinction is unambiguous throughout
