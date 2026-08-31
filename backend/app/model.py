"""Memory-efficient inference for the published BasirahAI DR checkpoint.

The Docker build converts the trusted fastai Learner pickle to a plain PyTorch
state dict. Runtime inference recreates the same model and validation transforms
without retaining fastai's Learner/DataLoaders machinery in memory.
"""

import os
from pathlib import Path

import torch
from PIL import Image
from torch import nn
from torchvision.models import resnet50
from torchvision.transforms import functional as TF

MODEL_REPO_ID = "jdelgado2002/diabetic_retinopathy_detection"
MODEL_STATE_PATH = Path(os.getenv("MODEL_STATE_PATH", "/model/basirah_resnet50_state.pt"))

NON_REFERABLE_GRADES = {0, 1}
GRADE_LABELS = {
    0: "No DR",
    1: "Mild",
    2: "Moderate",
    3: "Severe",
    4: "Proliferative DR",
}

_model: nn.Module | None = None


class AdaptiveConcatPool2d(nn.Module):
    """fastai-compatible adaptive max+average pooling."""

    def __init__(self, size: int = 1) -> None:
        super().__init__()
        self.ap = nn.AdaptiveAvgPool2d(size)
        self.mp = nn.AdaptiveMaxPool2d(size)

    def forward(self, value: torch.Tensor) -> torch.Tensor:
        return torch.cat([self.mp(value), self.ap(value)], dim=1)


def _build_model() -> nn.Module:
    backbone = resnet50(weights=None)
    body = nn.Sequential(*list(backbone.children())[:-2])
    head = nn.Sequential(
        AdaptiveConcatPool2d(),
        nn.Flatten(),
        nn.BatchNorm1d(4096),
        nn.Dropout(p=0.25),
        nn.Linear(4096, 512, bias=False),
        nn.ReLU(inplace=True),
        nn.BatchNorm1d(512),
        nn.Dropout(p=0.5),
        nn.Linear(512, 5, bias=False),
    )
    return nn.Sequential(body, head)


def load_model() -> nn.Module:
    """Load the converted model once at application startup."""
    global _model
    if _model is not None:
        return _model

    if not MODEL_STATE_PATH.is_file():
        raise FileNotFoundError(f"Converted model weights not found: {MODEL_STATE_PATH}")

    # Railway's trial container exposes one shared vCPU. PyTorch's host-sized
    # default thread pool causes severe oversubscription there (the first live
    # request took 83 seconds). Keep this configurable for larger future hosts.
    torch.set_num_threads(int(os.getenv("TORCH_NUM_THREADS", "1")))
    torch.set_num_interop_threads(1)

    loaded = _build_model()
    state_dict = torch.load(MODEL_STATE_PATH, map_location="cpu", weights_only=True)
    loaded.load_state_dict(state_dict)
    loaded.eval()
    _model = loaded
    return loaded


def is_model_loaded() -> bool:
    return _model is not None


def _prepare_image(image_path: str) -> torch.Tensor:
    """Reproduce the learner's deterministic validation transforms."""
    with Image.open(image_path) as source:
        image = source.convert("RGB")
        width, height = image.size
        crop_size = min(width, height)
        left = (width - crop_size) // 2
        top = (height - crop_size) // 2
        image = image.crop((left, top, left + crop_size, top + crop_size))
        image = image.resize((460, 460), resample=Image.Resampling.BILINEAR)

    tensor = TF.to_tensor(image).unsqueeze(0)
    # fastai's RandomResizedCropGPU validation path performs an identity
    # affine-grid resample of the full 460px square (not F.interpolate).
    identity = tensor.new_tensor(((1.0, 0.0, 0.0), (0.0, 1.0, 0.0))).unsqueeze(0)
    grid = torch.nn.functional.affine_grid(
        identity,
        (1, 3, 224, 224),
        align_corners=True,
    )
    # fastai prefilters larger downscales with area interpolation before
    # grid_sample to reduce aliasing.
    grid_min, grid_max = grid.min(), grid.max()
    zoom = 2 / (grid_max - grid_min).item()
    downscale = min(tensor.shape[-2] / grid.shape[-2], tensor.shape[-1] / grid.shape[-1]) / 2
    if downscale > 1 and downscale > zoom:
        tensor = torch.nn.functional.interpolate(
            tensor,
            scale_factor=1 / downscale,
            mode="area",
            recompute_scale_factor=True,
        )
    tensor = torch.nn.functional.grid_sample(
        tensor,
        grid,
        mode="bilinear",
        padding_mode="reflection",
        align_corners=True,
    )
    return TF.normalize(
        tensor,
        mean=(0.485, 0.456, 0.406),
        std=(0.229, 0.224, 0.225),
    )


def predict(image_path: str) -> dict:
    """Run inference while preserving the existing API response contract."""
    if _model is None:
        raise RuntimeError("Model not loaded - call load_model() at startup first.")

    tensor = _prepare_image(image_path)
    with torch.inference_mode():
        probs = torch.softmax(_model(tensor)[0], dim=0)

    raw_grade = int(probs.argmax().item())
    probs_list = [float(probability) for probability in probs]
    referable = raw_grade not in NON_REFERABLE_GRADES
    winning_grades = (
        set(GRADE_LABELS) - NON_REFERABLE_GRADES if referable else NON_REFERABLE_GRADES
    )
    confidence = sum(probs_list[index] for index in winning_grades)

    return {
        "referable": referable,
        "confidence": round(confidence, 4),
        "raw_grade": raw_grade,
        "raw_grade_label": GRADE_LABELS[raw_grade],
        "class_probabilities": [round(probability, 4) for probability in probs_list],
    }
