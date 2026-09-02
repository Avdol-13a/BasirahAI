import sys
from pathlib import Path

import pytest

# Make `app` importable regardless of the directory pytest was invoked from.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import model as model_module  # noqa: E402


@pytest.fixture(autouse=True)
def mock_model_loading(monkeypatch):
    """No test loads the real ~100MB checkpoint or runs a real torch forward
    pass through the full pipeline by default -- CI has no model weights to
    load. Individual tests that need specific prediction output monkeypatch
    `model.predict` (or `model._model`) further on top of this."""
    monkeypatch.setattr(model_module, "load_model", lambda: None)
    monkeypatch.setattr(model_module, "is_model_loaded", lambda: True)
    monkeypatch.setattr(
        model_module,
        "predict",
        lambda image_path: {
            "referable": False,
            "confidence": 0.95,
            "raw_grade": 0,
            "raw_grade_label": "No DR",
            "class_probabilities": [0.95, 0.03, 0.01, 0.005, 0.005],
        },
    )
    yield
