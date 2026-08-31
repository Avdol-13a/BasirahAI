"""
Independent sanity-check evaluation for BasirahAI's deployed /screen endpoint.

Runs every image in sample_manifest.csv (a stratified sample of the real
APTOS 2019 train split, downloaded via the Kaggle API — see select_sample.py
and download_sample.py) through the LIVE deployed backend, compares the
returned referable/non-referable call against the ground-truth diagnosis
grade (0-1 -> Non-Referable, 2-4 -> Referable, matching the app's own
convention in app/lib/models/result_category.dart), and reports real,
measured sensitivity/specificity/precision/F1/accuracy plus a confusion
matrix. Every number this script prints is real — nothing here is a
placeholder or a guess.
"""

import csv
import json
import sys
import time

import requests

sys.stdout.reconfigure(line_buffering=True)

BACKEND_URL = "https://basirahai-api-production.up.railway.app/screen"
LOW_CONFIDENCE_CUTOFF = 0.6  # matches app/lib/models/result_category.dart


def ground_truth_referable(grade: int) -> bool:
    return grade >= 2


def main():
    with open("sample_manifest.csv") as f:
        rows = list(csv.DictReader(f))

    results = []
    errors = []

    print(f"Running {len(rows)} images through {BACKEND_URL} ...")
    for i, row in enumerate(rows, 1):
        id_code = row["id_code"]
        true_grade = int(row["diagnosis"])
        image_path = f"images/{id_code}.png"

        pred = None
        last_err = None
        for attempt in range(4):
            try:
                with open(image_path, "rb") as img_f:
                    resp = requests.post(
                        BACKEND_URL,
                        files={"image": (f"{id_code}.png", img_f, "image/png")},
                        timeout=120,
                    )
                resp.raise_for_status()
                pred = resp.json()
                break
            except Exception as e:
                last_err = e
                if attempt < 3:
                    time.sleep(5 * (attempt + 1))

        if pred is None:
            errors.append((id_code, str(last_err)))
            print(f"  [{i}/{len(rows)}] {id_code}: ERROR - {last_err}")
            continue

        results.append(
            {
                "id_code": id_code,
                "true_grade": true_grade,
                "true_referable": ground_truth_referable(true_grade),
                "pred_referable": pred["referable"],
                "pred_confidence": pred["confidence"],
                "pred_raw_grade": pred["raw_grade"],
            }
        )

        if i % 20 == 0 or i == len(rows):
            print(f"  [{i}/{len(rows)}] done")

    with open("raw_results.json", "w") as f:
        json.dump({"results": results, "errors": errors}, f, indent=2)

    if errors:
        print(f"\n{len(errors)} images failed to score (see raw_results.json):")
        for id_code, err in errors[:10]:
            print(f"  {id_code}: {err}")

    n = len(results)
    if n == 0:
        print("No successful results — aborting metrics.")
        sys.exit(1)

    tp = sum(1 for r in results if r["true_referable"] and r["pred_referable"])
    tn = sum(1 for r in results if not r["true_referable"] and not r["pred_referable"])
    fp = sum(1 for r in results if not r["true_referable"] and r["pred_referable"])
    fn = sum(1 for r in results if r["true_referable"] and not r["pred_referable"])

    sensitivity = tp / (tp + fn) if (tp + fn) else float("nan")
    specificity = tn / (tn + fp) if (tn + fp) else float("nan")
    precision = tp / (tp + fp) if (tp + fp) else float("nan")
    f1 = (
        2 * precision * sensitivity / (precision + sensitivity)
        if (precision + sensitivity)
        else float("nan")
    )
    accuracy = (tp + tn) / n

    low_conf = [r for r in results if r["pred_confidence"] < LOW_CONFIDENCE_CUTOFF]

    print("\n" + "=" * 60)
    print(f"REAL, MEASURED RESULTS — {n} images scored, {len(errors)} errors")
    print("=" * 60)
    print(f"Sensitivity (recall) for Referable: {sensitivity:.4f}")
    print(f"Specificity:                        {specificity:.4f}")
    print(f"Precision:                           {precision:.4f}")
    print(f"F1:                                   {f1:.4f}")
    print(f"Accuracy:                             {accuracy:.4f}")
    print()
    print("Confusion matrix:")
    print(f"                        Predicted: Non-Referable   Predicted: Referable")
    print(f"Actual: Non-Referable          {tn:<8}                    {fp:<8}")
    print(f"Actual: Referable              {fn:<8}                    {tp:<8}")
    print()
    print(f"Low-confidence (<{LOW_CONFIDENCE_CUTOFF}) count: {len(low_conf)} / {n}")

    with open("metrics_summary.json", "w") as f:
        json.dump(
            {
                "n_scored": n,
                "n_errors": len(errors),
                "sensitivity": sensitivity,
                "specificity": specificity,
                "precision": precision,
                "f1": f1,
                "accuracy": accuracy,
                "confusion_matrix": {"tp": tp, "tn": tn, "fp": fp, "fn": fn},
                "low_confidence_count": len(low_conf),
                "low_confidence_cutoff": LOW_CONFIDENCE_CUTOFF,
            },
            f,
            indent=2,
        )
    print("\nSaved raw_results.json and metrics_summary.json")


if __name__ == "__main__":
    main()
