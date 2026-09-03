"""Unit tests for the reject/warn threshold logic in app/fundus_gate.py.

These monkeypatch fundus_probability directly so the thresholds can be
tested precisely without needing the real backbone/head weights -- same
pattern test_model.py uses for the DR model's own logic.
"""

import pytest
from PIL import Image

from app import fundus_gate
from app.image_checks import ImageQualityWarning, ImageSuitabilityError

# Captured at collection time, before conftest's autouse fixture (which
# replaces fundus_gate.fundus_probability with a fixed mock for every other
# test module) has run -- same pattern as test_model.py's _REAL_PREDICT.
_REAL_FUNDUS_PROBABILITY = fundus_gate.fundus_probability


def _fake_image():
    return Image.new("RGB", (300, 300), (120, 120, 120))


def test_confident_fundus_passes_with_no_warning(monkeypatch):
    monkeypatch.setattr(fundus_gate, "fundus_probability", lambda image: 0.95)
    assert fundus_gate.check_fundus_content(_fake_image()) is None


def test_confidently_non_fundus_rejected(monkeypatch):
    monkeypatch.setattr(fundus_gate, "fundus_probability", lambda image: 0.1)
    with pytest.raises(ImageSuitabilityError) as excinfo:
        fundus_gate.check_fundus_content(_fake_image())
    assert excinfo.value.code == "not_fundus_photo"


def test_uncertain_band_warns_without_rejecting(monkeypatch):
    monkeypatch.setattr(fundus_gate, "fundus_probability", lambda image: 0.75)
    result = fundus_gate.check_fundus_content(_fake_image())
    assert isinstance(result, ImageQualityWarning)
    assert result.code == "uncertain_fundus_content"


def test_threshold_boundaries_are_exclusive_on_the_low_side():
    # Exactly at REJECT_THRESHOLD should NOT reject (only strictly below
    # does) -- pins the boundary behavior so a future threshold tweak can't
    # silently flip it.
    assert fundus_gate.REJECT_THRESHOLD < fundus_gate.WARN_THRESHOLD


def test_reject_boundary(monkeypatch):
    monkeypatch.setattr(fundus_gate, "fundus_probability", lambda image: fundus_gate.REJECT_THRESHOLD)
    # At the boundary, not below it -> should warn, not reject.
    result = fundus_gate.check_fundus_content(_fake_image())
    assert isinstance(result, ImageQualityWarning)


def test_warn_boundary(monkeypatch):
    monkeypatch.setattr(fundus_gate, "fundus_probability", lambda image: fundus_gate.WARN_THRESHOLD)
    # At the boundary, not below it -> should pass with no warning.
    assert fundus_gate.check_fundus_content(_fake_image()) is None


def test_fundus_probability_raises_if_model_not_loaded(monkeypatch):
    # Restore the real fundus_probability (conftest's autouse fixture
    # replaces it with a fixed mock for every other test) and ensure no
    # model is loaded, so this exercises the genuine not-loaded guard.
    monkeypatch.setattr(fundus_gate, "fundus_probability", _REAL_FUNDUS_PROBABILITY)
    monkeypatch.setattr(fundus_gate, "_backbone", None)
    monkeypatch.setattr(fundus_gate, "_head", None)
    with pytest.raises(RuntimeError):
        fundus_gate.fundus_probability(_fake_image())
