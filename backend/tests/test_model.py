"""Unit tests for the binary referable/confidence derivation in app/model.py.

These bypass the real torch forward pass by swapping in a tiny fake module
whose logits are chosen so that softmax(logits) reproduces an exact,
hand-picked probability distribution (via logits = log(probs)) -- this lets
each test assert on precise, known probabilities without needing the real
checkpoint.
"""

import pytest
import torch
from PIL import Image

from app import model as model_module

# Captured at collection time, before conftest's autouse fixture (which
# replaces model.predict with a fixed mock for every other test module) has
# run -- these tests are exercising the real aggregation logic in predict()
# itself, so they need the genuine function restored.
_REAL_PREDICT = model_module.predict


class _FakeModel(torch.nn.Module):
    def __init__(self, logits: torch.Tensor):
        super().__init__()
        self._logits = logits

    def forward(self, x):  # noqa: D401 - torch API
        return self._logits.unsqueeze(0)


@pytest.fixture(autouse=True)
def _use_real_predict(monkeypatch):
    monkeypatch.setattr(model_module, "predict", _REAL_PREDICT)
    yield
    model_module._model = None


def _make_test_image(path) -> None:
    Image.new("RGB", (300, 300), (120, 120, 120)).save(path)


def _predict_with_probs(tmp_path, probs_list):
    image_path = tmp_path / "img.jpg"
    _make_test_image(image_path)
    logits = torch.log(torch.tensor(probs_list, dtype=torch.float32))
    model_module._model = _FakeModel(logits)
    return model_module.predict(str(image_path))


def test_predict_response_schema(tmp_path):
    result = _predict_with_probs(tmp_path, [0.95, 0.03, 0.01, 0.005, 0.005])
    assert set(result.keys()) == {
        "referable",
        "confidence",
        "raw_grade",
        "raw_grade_label",
        "class_probabilities",
    }
    assert isinstance(result["referable"], bool)
    assert isinstance(result["raw_grade"], int)
    assert isinstance(result["raw_grade_label"], str)
    assert len(result["class_probabilities"]) == 5
    assert abs(sum(result["class_probabilities"]) - 1.0) < 1e-2


def test_predict_clear_non_referable(tmp_path):
    result = _predict_with_probs(tmp_path, [0.95, 0.03, 0.01, 0.005, 0.005])
    assert result["raw_grade"] == 0
    assert result["raw_grade_label"] == "No DR"
    assert result["referable"] is False
    assert result["confidence"] > 0.9


def test_predict_clear_referable(tmp_path):
    result = _predict_with_probs(tmp_path, [0.01, 0.01, 0.05, 0.13, 0.80])
    assert result["raw_grade"] == 4
    assert result["raw_grade_label"] == "Proliferative DR"
    assert result["referable"] is True
    assert result["confidence"] > 0.9


def test_predict_argmax_and_aggregate_disagree(tmp_path):
    """raw_grade (the single largest class) can disagree with the referable
    call, which is decided from the *summed* binary probability mass, not
    from which side raw_grade happens to fall on. This is documented,
    intentional behavior -- see the comment above the aggregation in
    app/model.py's predict()."""
    # argmax is index 1 ("Mild", non-referable, p=0.30) but grades 2-4 sum to
    # 0.65 > grades 0-1's 0.35, so the binary call goes the other way.
    result = _predict_with_probs(tmp_path, [0.05, 0.30, 0.28, 0.22, 0.15])
    assert result["raw_grade"] == 1
    assert result["raw_grade_label"] == "Mild"
    assert result["referable"] is True
    assert abs(result["confidence"] - 0.65) < 0.02


def test_predict_tie_favors_referable(tmp_path):
    """An exact tie between the two sides' aggregate mass resolves to
    referable (the `>=` in the comparison), the more conservative/sensitive
    choice for a screening tool."""
    result = _predict_with_probs(tmp_path, [0.25, 0.25, 0.25, 0.25, 0.0])
    assert result["referable"] is True
    assert abs(result["confidence"] - 0.5) < 0.02


def test_predict_raises_if_model_not_loaded(tmp_path):
    model_module._model = None
    image_path = tmp_path / "img.jpg"
    _make_test_image(image_path)
    with pytest.raises(RuntimeError):
        model_module.predict(str(image_path))
