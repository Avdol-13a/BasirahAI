"""Convert the trusted fastai checkpoint into a plain PyTorch state dict.

This runs only in the Docker build stage. Production never imports fastai,
which removes the Learner/DataLoaders overhead that pushed the service over
Render Free's 512 MB memory limit.
"""

import __main__
import os
import pathlib
import sys
from pathlib import Path

import torch
from huggingface_hub import from_pretrained_fastai

MODEL_REPO_ID = "jdelgado2002/diabetic_retinopathy_detection"
OUTPUT_PATH = Path(
    sys.argv[1] if len(sys.argv) > 1 else os.getenv("MODEL_STATE_PATH", "/model/basirah_resnet50_state.pt")
)

__main__.get_x = lambda x: x
__main__.get_y = lambda x: x
if os.name == "nt":
    pathlib.PosixPath = pathlib.WindowsPath

learner = from_pretrained_fastai(MODEL_REPO_ID)
OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
torch.save(learner.model.state_dict(), OUTPUT_PATH)
