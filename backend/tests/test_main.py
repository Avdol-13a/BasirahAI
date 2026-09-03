import io

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app import main as main_module


@pytest.fixture
def client():
    with TestClient(main_module.app) as test_client:
        yield test_client


def _textured_jpeg_bytes(size=(400, 400)) -> bytes:
    image = Image.new("RGB", size)
    pixels = image.load()
    width, height = size
    for x in range(width):
        for y in range(height):
            pixels[x, y] = ((x * 7 + y * 13) % 256, (x * 3) % 256, (y * 5) % 256)
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG")
    return buffer.getvalue()


def _solid_jpeg_bytes(size, color) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", size, color).save(buffer, format="JPEG")
    return buffer.getvalue()


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "model_loaded": True, "fundus_gate_loaded": True}


def test_screen_empty_file_rejected(client):
    response = client.post("/screen", files={"image": ("photo.jpg", b"", "image/jpeg")})
    assert response.status_code == 400
    assert response.json()["detail"] == "Uploaded file is empty."


def test_screen_non_image_file_rejected(client):
    response = client.post(
        "/screen", files={"image": ("notes.txt", b"this is not an image", "text/plain")}
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "This doesn't look like a valid image file."


def test_screen_oversized_file_rejected(client):
    oversized = b"\x00" * (main_module.MAX_UPLOAD_BYTES + 1)
    response = client.post("/screen", files={"image": ("photo.jpg", oversized, "image/jpeg")})
    assert response.status_code == 413
    assert "too large" in response.json()["detail"]


def test_screen_tiny_image_rejected(client):
    tiny = _solid_jpeg_bytes((10, 10), (128, 128, 128))
    response = client.post("/screen", files={"image": ("photo.jpg", tiny, "image/jpeg")})
    assert response.status_code == 400
    assert "too small" in response.json()["detail"]


def test_screen_decompression_bomb_guard(client, monkeypatch):
    # Use a small real image but drop the pixel-count ceiling below its
    # actual pixel count, so the guard path is exercised without needing to
    # construct an actual multi-hundred-megapixel file.
    monkeypatch.setattr(main_module, "MAX_IMAGE_PIXELS", 100)
    normal = _textured_jpeg_bytes((400, 400))
    response = client.post("/screen", files={"image": ("photo.jpg", normal, "image/jpeg")})
    assert response.status_code == 400
    assert "too large to analyze" in response.json()["detail"]


def test_screen_unsuitable_image_returns_structured_error(client):
    dark = _solid_jpeg_bytes((400, 400), (2, 2, 2))
    response = client.post("/screen", files={"image": ("photo.jpg", dark, "image/jpeg")})
    assert response.status_code == 400
    detail = response.json()["detail"]
    assert isinstance(detail, dict)
    assert detail["code"] == "too_dark"
    assert "message" in detail


def test_screen_valid_image_returns_mocked_result(client):
    good = _textured_jpeg_bytes()
    response = client.post("/screen", files={"image": ("photo.jpg", good, "image/jpeg")})
    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {
        "referable",
        "confidence",
        "raw_grade",
        "raw_grade_label",
        "class_probabilities",
        "quality_warnings",
    }
    assert body["quality_warnings"] == []


def _soft_gradient_jpeg_bytes(size=(300, 300)) -> bytes:
    """Soft-but-not-degenerate image: lands in the blur gate's warn band, not
    its reject floor, *after* the lossy JPEG round-trip the real upload path
    also goes through (JPEG re-encoding further softens a low-amplitude
    gradient, so the amplitude here is picked to still clear the reject
    floor post-encode -- see backend/tests/test_image_checks.py for the
    pre-encode version of this fixture and the reasoning behind the
    thresholds)."""
    image = Image.new("RGB", size)
    pixels = image.load()
    width, height = size
    for x in range(width):
        for y in range(height):
            value = 120 + int(10 * ((x + y) % 40) / 40)
            pixels[x, y] = (value, value, value)
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG")
    return buffer.getvalue()


def test_screen_soft_image_scored_with_warning_not_rejected(client):
    """Regression for the 2026-09-03 blur-gate recalibration: a clinically
    usable but soft image must be scored (200), carrying a quality warning,
    never hard-rejected the way it was before the fix."""
    soft = _soft_gradient_jpeg_bytes()
    response = client.post("/screen", files={"image": ("photo.jpg", soft, "image/jpeg")})
    assert response.status_code == 200
    warnings = response.json()["quality_warnings"]
    assert len(warnings) == 1
    assert warnings[0]["code"] == "soft_focus"


def test_screen_logs_raw_model_output(client, caplog):
    """Raw model output must be traceable independent of how the response is
    later converted/displayed -- see dev/HANDOFF.md."""
    good = _textured_jpeg_bytes()
    with caplog.at_level("INFO", logger="basirah"):
        response = client.post("/screen", files={"image": ("photo.jpg", good, "image/jpeg")})
    assert response.status_code == 200
    assert any("Raw model output" in record.message for record in caplog.records)
    assert any("raw_grade" in record.message for record in caplog.records)


def test_screen_non_fundus_content_rejected(client, monkeypatch):
    """Regression for the 2026-09-03 content-gate addition: a structurally
    fine, sharp, well-exposed image that the fundus-content classifier is
    confident is NOT a fundus photo (e.g. the real bug -- the app's own
    logo) must be rejected, not scored."""
    monkeypatch.setattr(main_module.fundus_gate, "fundus_probability", lambda image: 0.1)
    good = _textured_jpeg_bytes()
    response = client.post("/screen", files={"image": ("photo.jpg", good, "image/jpeg")})
    assert response.status_code == 400
    detail = response.json()["detail"]
    assert detail["code"] == "not_fundus_photo"


def test_screen_uncertain_fundus_content_scored_with_warning(client, monkeypatch):
    """The warn band (between the reject floor and the observed real-fundus
    floor) must still be scored, with a quality warning attached -- same
    non-blocking pattern as the blur gate, so a genuine but unusual photo
    isn't silently refused."""
    monkeypatch.setattr(main_module.fundus_gate, "fundus_probability", lambda image: 0.75)
    good = _textured_jpeg_bytes()
    response = client.post("/screen", files={"image": ("photo.jpg", good, "image/jpeg")})
    assert response.status_code == 200
    warnings = response.json()["quality_warnings"]
    assert len(warnings) == 1
    assert warnings[0]["code"] == "uncertain_fundus_content"


def test_screen_confident_fundus_content_no_warning(client, monkeypatch):
    monkeypatch.setattr(main_module.fundus_gate, "fundus_probability", lambda image: 0.95)
    good = _textured_jpeg_bytes()
    response = client.post("/screen", files={"image": ("photo.jpg", good, "image/jpeg")})
    assert response.status_code == 200
    assert response.json()["quality_warnings"] == []


def test_screen_busy_returns_503(client, monkeypatch):
    monkeypatch.setattr(main_module, "_active_inferences", main_module.MAX_CONCURRENT_INFERENCE)
    good = _textured_jpeg_bytes()
    response = client.post("/screen", files={"image": ("photo.jpg", good, "image/jpeg")})
    assert response.status_code == 503
    assert main_module._active_inferences == main_module.MAX_CONCURRENT_INFERENCE


def test_screen_releases_slot_and_cleans_up_temp_file_on_inference_failure(
    client, monkeypatch, tmp_path
):
    created_paths = []
    real_named_temp_file = main_module.tempfile.NamedTemporaryFile

    def _tracking_named_temp_file(*args, **kwargs):
        handle = real_named_temp_file(*args, **kwargs)
        created_paths.append(handle.name)
        return handle

    monkeypatch.setattr(main_module.tempfile, "NamedTemporaryFile", _tracking_named_temp_file)
    monkeypatch.setattr(
        main_module.model,
        "predict",
        lambda path: (_ for _ in ()).throw(RuntimeError("boom")),
    )

    good = _textured_jpeg_bytes()
    response = client.post("/screen", files={"image": ("photo.jpg", good, "image/jpeg")})

    assert response.status_code == 500
    assert created_paths, "expected a temp file to have been created"
    assert not main_module.os.path.exists(created_paths[0]), "temp file must be cleaned up on failure"
    assert main_module._active_inferences == 0, "inference slot must be released on failure"
