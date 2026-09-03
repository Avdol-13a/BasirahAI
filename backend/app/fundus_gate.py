"""Pre-filter: is this image even a retinal fundus photo?

Added 2026-09-03 after a real production bug: the existing suitability
checks (aspect ratio, exposure, blur -- image_checks.py) never verify
content, only quality. A clearly unrelated image (this app's own logo) was
confirmed to sail through them and get a confident, wrong DR result. A
cheap color-based heuristic was tried first and rejected -- real fundus
photos and common warm-toned objects (skin, wood, brick) turned out to have
overlapping red-channel dominance, so it would have caught cool-toned junk
but waved through the single most likely accidental input (a photo of a
hand). See docs/FUNDUS_GATE.md for the full investigation.

This uses a frozen, ImageNet-pretrained MobileNetV3-Small backbone (the
same torchvision dependency model.py already uses, ~10MB) as a feature
extractor, plus a small logistic head trained specifically for this
project (backend/train_fundus_gate.py) on real fundus photos (positive)
against real CIFAR-10 photos and procedurally generated flat/graphic images
(negative). Both the reject and warn thresholds below were picked from
real measured numbers on held-out data, not guessed -- see
docs/FUNDUS_GATE.md and eval_data/fundus_gate_metrics.json.

This is still a heuristic pre-filter, not a certified fundus-photo
detector: it never proves an image is clinically adequate, and its
negative training data cannot cover every possible non-fundus photo. False
accepts of unusual-but-real non-fundus images remain possible. It should
reduce, not eliminate, the failure mode it targets.
"""

import os
from pathlib import Path

import torch
from PIL import Image
from torch import nn
from torchvision.models import MobileNet_V3_Small_Weights, mobilenet_v3_small

from .image_checks import ImageQualityWarning, ImageSuitabilityError

BACKBONE_PATH = Path(
    os.getenv("FUNDUS_GATE_BACKBONE_PATH", "/model/mobilenet_v3_small_backbone.pt")
)
HEAD_PATH = Path(
    os.getenv("FUNDUS_GATE_HEAD_PATH", str(Path(__file__).parent / "fundus_gate_head.pt"))
)
FEATURE_DIM = 576

# Calibrated from real measurements (backend/train_fundus_gate.py's output,
# recorded in eval_data/fundus_gate_metrics.json): across all 201 real
# fundus photos in this project's evaluation sample, the lowest
# fundus-probability score was 0.8575 (p0), with p1=0.8874, p5=0.9462. A 9
# image sanity set of known non-fundus content (the app logo, icons, UI
# screenshots -- none used in training) scored at most 0.5682. REJECT sits
# well below every real fundus photo observed; WARN sits just below the
# real observed floor, as a safety margin for genuine photos this specific
# 201-image sample didn't happen to cover.
REJECT_THRESHOLD = float(os.getenv("FUNDUS_GATE_REJECT_THRESHOLD", "0.7"))
WARN_THRESHOLD = float(os.getenv("FUNDUS_GATE_WARN_THRESHOLD", "0.85"))

_backbone: nn.Module | None = None
_head: nn.Module | None = None
_preprocess = None


def load_model() -> None:
    """Load the frozen backbone and the trained head once at startup."""
    global _backbone, _head, _preprocess
    if _backbone is not None:
        return

    if not BACKBONE_PATH.is_file():
        raise FileNotFoundError(f"Fundus-gate backbone weights not found: {BACKBONE_PATH}")
    if not HEAD_PATH.is_file():
        raise FileNotFoundError(f"Fundus-gate head weights not found: {HEAD_PATH}")

    backbone = mobilenet_v3_small(weights=None)
    backbone.load_state_dict(torch.load(BACKBONE_PATH, map_location="cpu", weights_only=True))
    backbone.eval()
    for p in backbone.parameters():
        p.requires_grad_(False)

    head = nn.Linear(FEATURE_DIM, 1)
    head.load_state_dict(torch.load(HEAD_PATH, map_location="cpu", weights_only=True))
    head.eval()

    _backbone = backbone
    _head = head
    _preprocess = MobileNet_V3_Small_Weights.IMAGENET1K_V1.transforms()


def is_model_loaded() -> bool:
    return _backbone is not None and _head is not None


def fundus_probability(image: Image.Image) -> float:
    """Return the classifier's estimated probability this image is a
    genuine retinal fundus photo (0-1)."""
    if _backbone is None or _head is None or _preprocess is None:
        raise RuntimeError("Fundus-gate model not loaded - call load_model() at startup first.")

    tensor = _preprocess(image).unsqueeze(0)
    with torch.inference_mode():
        features = _backbone.avgpool(_backbone.features(tensor)).flatten(1)
        probability = torch.sigmoid(_head(features))
    return float(probability.item())


def check_fundus_content(image: Image.Image) -> ImageQualityWarning | None:
    """Raise ImageSuitabilityError if the image is confidently not a fundus
    photo; return a non-blocking ImageQualityWarning for the uncertain
    middle band; return None when confidently fundus-like."""
    probability = fundus_probability(image)

    if probability < REJECT_THRESHOLD:
        raise ImageSuitabilityError(
            "not_fundus_photo",
            "This doesn't look like a retinal fundus photo. Please capture or select a fundus image.",
        )
    if probability < WARN_THRESHOLD:
        return ImageQualityWarning(
            "uncertain_fundus_content",
            "This photo doesn't clearly look like a retinal fundus photo. "
            "The result may not be meaningful — please make sure you're capturing a fundus image.",
        )
    return None
