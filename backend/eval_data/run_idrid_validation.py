"""External validation: run the UNCHANGED, currently-deployed fundus-content
gate (and the full image-suitability pipeline) against IDRiD -- a genuinely
different retinal fundus dataset never used for training or threshold
calibration (backend/train_fundus_gate.py used APTOS positives + CIFAR-10 /
synthetic negatives only).

This script does NOT train, fine-tune, or touch any threshold. It only
scores images and reports results, so a threshold decision can be made from
real evidence afterward. See docs/FUNDUS_GATE.md for the calibration this
is being checked against.

Usage:
    python run_idrid_validation.py <path to IDRiD manifest file>

The manifest is a tab-separated file of (label, filename, md5, path) rows,
already deduplicated by content hash across IDRiD's A/B/C original-image
folders (B and C are byte-identical; some overlap exists with A too).
"""

import json
import statistics
import sys
import time

sys.path.insert(0, "..")

from PIL import Image, UnidentifiedImageError

from app import fundus_gate
from app.image_checks import ImageSuitabilityError, check_image_suitability


def load_manifest(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            label, filename, md5, image_path = line.rstrip("\n").split("\t")
            rows.append((label, filename, image_path))
    return rows


def percentile(sorted_values, p):
    if not sorted_values:
        return float("nan")
    idx = min(len(sorted_values) - 1, int(len(sorted_values) * p / 100))
    return sorted_values[idx]


def main():
    manifest_path = sys.argv[1] if len(sys.argv) > 1 else "idrid_manifest.txt"
    rows = load_manifest(manifest_path)
    print(f"Loaded manifest: {len(rows)} unique IDRiD fundus images")

    print("Loading fundus-gate model (unchanged, currently deployed thresholds)...")
    fundus_gate.load_model()
    print(f"  REJECT_THRESHOLD={fundus_gate.REJECT_THRESHOLD}  WARN_THRESHOLD={fundus_gate.WARN_THRESHOLD}")

    results = []
    errors = []
    start = time.time()
    for i, (label, filename, image_path) in enumerate(rows, 1):
        try:
            image = Image.open(image_path).convert("RGB")
        except (UnidentifiedImageError, OSError) as e:
            errors.append({"label": label, "filename": filename, "error": str(e)})
            continue

        # (7) Full existing pipeline, not just the ML gate: aspect ratio,
        # exposure, blur. Recorded separately from the fundus-gate score so
        # we can see whether any *other* check would reject a legitimate
        # IDRiD photo.
        pipeline_rejected = False
        pipeline_reject_code = None
        pipeline_warnings = []
        try:
            warnings = check_image_suitability(image)
            pipeline_warnings = [w.code for w in warnings]
        except ImageSuitabilityError as e:
            pipeline_rejected = True
            pipeline_reject_code = e.code

        fundus_prob = fundus_gate.fundus_probability(image)

        results.append(
            {
                "label": label,
                "filename": filename,
                "path": image_path,
                "fundus_probability": fundus_prob,
                "pipeline_rejected_by_other_check": pipeline_rejected,
                "pipeline_reject_code": pipeline_reject_code,
                "pipeline_warnings": pipeline_warnings,
            }
        )
        if i % 100 == 0 or i == len(rows):
            print(f"  [{i}/{len(rows)}] scored")

    print(f"Done in {time.time() - start:.1f}s. {len(results)} scored, {len(errors)} errors.")

    probs = sorted(r["fundus_probability"] for r in results)
    n = len(probs)

    n_reject = sum(1 for p in probs if p < fundus_gate.REJECT_THRESHOLD)
    n_warn = sum(1 for p in probs if fundus_gate.REJECT_THRESHOLD <= p < fundus_gate.WARN_THRESHOLD)
    n_pass = sum(1 for p in probs if p >= fundus_gate.WARN_THRESHOLD)

    n_other_check_rejected = sum(1 for r in results if r["pipeline_rejected_by_other_check"])
    other_reject_codes = {}
    for r in results:
        if r["pipeline_reject_code"]:
            other_reject_codes[r["pipeline_reject_code"]] = other_reject_codes.get(r["pipeline_reject_code"], 0) + 1

    summary = {
        "n_total": n,
        "n_errors": len(errors),
        "min": probs[0],
        "max": probs[-1],
        "mean": statistics.mean(probs),
        "median": statistics.median(probs),
        "p1": percentile(probs, 1),
        "p5": percentile(probs, 5),
        "p10": percentile(probs, 10),
        "p25": percentile(probs, 25),
        "n_reject_below_0.70": n_reject,
        "pct_reject_below_0.70": round(100 * n_reject / n, 2),
        "n_warn_0.70_to_0.85": n_warn,
        "pct_warn_0.70_to_0.85": round(100 * n_warn / n, 2),
        "n_pass_above_0.85": n_pass,
        "pct_pass_above_0.85": round(100 * n_pass / n, 2),
        "n_rejected_by_OTHER_checks_aspect_exposure_blur": n_other_check_rejected,
        "other_check_reject_codes": other_reject_codes,
        "reject_threshold": fundus_gate.REJECT_THRESHOLD,
        "warn_threshold": fundus_gate.WARN_THRESHOLD,
        "previous_calibration_real_fundus_floor": 0.8575,
        "previous_calibration_known_non_fundus_ceiling": 0.5682,
    }

    print("\n" + "=" * 60)
    print("IDRiD EXTERNAL VALIDATION SUMMARY")
    print("=" * 60)
    for k, v in summary.items():
        print(f"  {k}: {v}")

    lowest_20 = sorted(results, key=lambda r: r["fundus_probability"])[:20]
    print("\n20 lowest-scoring IDRiD images:")
    for r in lowest_20:
        print(f"  {r['filename']}: {r['fundus_probability']:.4f}  (other-check rejected: {r['pipeline_rejected_by_other_check']}, code: {r['pipeline_reject_code']})")

    with open("idrid_validation_results.json", "w") as f:
        json.dump({"summary": summary, "results": results, "errors": errors, "lowest_20": lowest_20}, f, indent=2)
    print("\nSaved full raw results to eval_data/idrid_validation_results.json")


if __name__ == "__main__":
    main()
