import pytest
from PIL import Image

from app import image_checks as checks


def _textured_image(size=(400, 400)):
    """A non-flat, normally-exposed synthetic image that should pass every
    suitability check (used as the "genuine photo" baseline these
    conservative heuristics must not false-reject)."""
    image = Image.new("RGB", size)
    pixels = image.load()
    width, height = size
    for x in range(width):
        for y in range(height):
            pixels[x, y] = ((x * 7 + y * 13) % 256, (x * 3) % 256, (y * 5) % 256)
    return image


def test_textured_image_passes_all_checks():
    checks.check_image_suitability(_textured_image())  # should not raise


def test_bad_aspect_ratio_rejected():
    with pytest.raises(checks.ImageSuitabilityError) as excinfo:
        checks.check_aspect_ratio(Image.new("RGB", (1000, 50), (128, 128, 128)))
    assert excinfo.value.code == "bad_aspect_ratio"


def test_normal_aspect_ratio_passes():
    checks.check_aspect_ratio(Image.new("RGB", (400, 300)))  # should not raise
    checks.check_aspect_ratio(Image.new("RGB", (300, 400)))  # portrait too


def test_too_dark_rejected():
    with pytest.raises(checks.ImageSuitabilityError) as excinfo:
        checks.check_exposure_and_blur(Image.new("RGB", (300, 300), (2, 2, 2)))
    assert excinfo.value.code == "too_dark"


def test_too_bright_rejected():
    with pytest.raises(checks.ImageSuitabilityError) as excinfo:
        checks.check_exposure_and_blur(Image.new("RGB", (300, 300), (253, 253, 253)))
    assert excinfo.value.code == "too_bright"


def test_flat_midtone_image_rejected_as_blurry():
    # Perfectly flat -> zero edge variance -> "too_blurry", even though its
    # brightness (128) is well within the normal exposure range.
    with pytest.raises(checks.ImageSuitabilityError) as excinfo:
        checks.check_exposure_and_blur(Image.new("RGB", (300, 300), (128, 128, 128)))
    assert excinfo.value.code == "too_blurry"


def test_checkerboard_passes_blur_check():
    image = Image.new("RGB", (300, 300))
    pixels = image.load()
    for x in range(300):
        for y in range(300):
            value = 128 if (x // 5 + y // 5) % 2 == 0 else 20
            pixels[x, y] = (value, value, value)
    checks.check_exposure_and_blur(image)  # should not raise


def test_fundus_shape_check_disabled_by_default():
    assert checks.ENABLE_FUNDUS_SHAPE_CHECK is False
    # Would fail a coverage heuristic if the check ran -- must not raise
    # while the flag is off.
    checks.check_fundus_like_structure(Image.new("RGB", (300, 300), (2, 2, 2)))


def test_fundus_shape_check_when_enabled(monkeypatch):
    monkeypatch.setattr(checks, "ENABLE_FUNDUS_SHAPE_CHECK", True)
    with pytest.raises(checks.ImageSuitabilityError) as excinfo:
        checks.check_fundus_like_structure(Image.new("RGB", (300, 300), (2, 2, 2)))
    assert excinfo.value.code == "not_fundus_like"


def test_fundus_shape_check_when_enabled_allows_bright_field(monkeypatch):
    monkeypatch.setattr(checks, "ENABLE_FUNDUS_SHAPE_CHECK", True)
    checks.check_fundus_like_structure(_textured_image())  # should not raise


def test_blur_check_downsamples_large_images_bounding_memory(monkeypatch):
    """A large image's Laplacian variance must be computed on a downsampled
    copy (see _BLUR_CHECK_MAX_DIMENSION) -- an ungated float64 array at, say,
    40 megapixels would cost ~320MB for this check alone. Lower the cap so a
    "large" image is cheap to construct in a test, and assert the function
    never materializes an array bigger than the capped dimensions."""
    monkeypatch.setattr(checks, "_BLUR_CHECK_MAX_DIMENSION", 50)
    large_textured = _textured_image(size=(2000, 2000))

    original_asarray = checks.np.asarray
    seen_shapes = []

    def _tracking_asarray(obj, *args, **kwargs):
        result = original_asarray(obj, *args, **kwargs)
        seen_shapes.append(result.shape)
        return result

    monkeypatch.setattr(checks.np, "asarray", _tracking_asarray)

    checks.check_exposure_and_blur(large_textured)  # should not raise, and should not OOM

    assert seen_shapes, "expected the Laplacian computation to run"
    height, width = seen_shapes[0]
    assert max(height, width) <= 50
