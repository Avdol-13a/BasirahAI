"""One-off diagnostic: compare the original fastai Learner's predict() against
the production bare-torch pipeline (backend/app/model.py) on real images,
including the documented false-negative case from the 201-image evaluation.

Not part of the app or test suite -- a throwaway investigation script kept
for reproducibility (see docs/ML_PLAN.md's "Label mapping and pipeline-parity
re-verification" section). Requires a converted state dict first:

    python export_model.py eval_data/model_out/state.pt

(eval_data/model_out/ is gitignored -- ~100MB, regenerate locally, don't commit it.)
"""
import os
import pathlib
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import __main__
import numpy as np
import torch

__main__.get_x = lambda x: x
__main__.get_y = lambda x: x
if os.name == "nt":
    pathlib.PosixPath = pathlib.WindowsPath

from huggingface_hub import from_pretrained_fastai

os.environ["MODEL_STATE_PATH"] = os.path.join(os.path.dirname(__file__), "model_out", "state.pt")

from app import model as bare_model  # noqa: E402

print("Loading fastai learner...")
learner = from_pretrained_fastai("jdelgado2002/diabetic_retinopathy_detection")
print("vocab:", learner.dls.vocab)

print("Loading bare-torch model...")
bare_model.load_model()

images = [
    "a06e41bd2634.png",  # the documented false negative: true grade 2, predicted non-referable @97.43%
    "25e9fd872182.png",  # false positive: true grade 1, predicted referable @99.98%
    "959bb2d01091.png",  # arbitrary sanity check
]

for fname in images:
    path = os.path.join(os.path.dirname(__file__), "images", fname)
    if not os.path.isfile(path):
        print(f"missing {path}")
        continue

    # --- original fastai pipeline ---
    _, _, fastai_probs = learner.predict(path)
    fastai_probs = fastai_probs.numpy()

    # --- production bare-torch pipeline ---
    result = bare_model.predict(path)

    print(f"\n=== {fname} ===")
    print("fastai probs:      ", np.round(fastai_probs, 4).tolist())
    print("bare-torch probs:  ", result["class_probabilities"])
    print("bare-torch raw_grade:", result["raw_grade"], result["raw_grade_label"])
    print("bare-torch referable:", result["referable"], "confidence:", result["confidence"])
    print("max abs prob diff: ", float(np.max(np.abs(fastai_probs - np.array(result["class_probabilities"])))))
