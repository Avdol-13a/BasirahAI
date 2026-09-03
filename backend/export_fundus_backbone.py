"""Convert MobileNetV3-Small's ImageNet-pretrained backbone to a plain state
dict during the Docker build stage, mirroring export_model.py's reasoning
for the DR model: the running container should never need a network call
(here, to download.pytorch.org) to serve a request. Only the backbone is
exported -- the trained classification head lives in app/fundus_gate_head.pt
(tiny, committed directly to the repo, no build-time step needed for it).

See backend/app/fundus_gate.py for how both pieces are loaded together, and
docs/FUNDUS_GATE.md for why this pre-filter exists.
"""

import os
import sys
from pathlib import Path

import torch
from torchvision.models import MobileNet_V3_Small_Weights, mobilenet_v3_small

OUTPUT_PATH = Path(
    sys.argv[1] if len(sys.argv) > 1 else os.getenv("FUNDUS_GATE_BACKBONE_PATH", "/model/mobilenet_v3_small_backbone.pt")
)

backbone = mobilenet_v3_small(weights=MobileNet_V3_Small_Weights.IMAGENET1K_V1)
OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
torch.save(backbone.state_dict(), OUTPUT_PATH)
