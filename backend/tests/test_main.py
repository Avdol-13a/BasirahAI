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
    assert response.json() == {"status": "ok", "model_loaded": True}


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
    }


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
