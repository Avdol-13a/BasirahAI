"""Lightweight, non-ML heuristics that flag images unsuitable for screening.

These catch clearly-bad input (near-black or blown-out frames, motion-blurred
shots, extreme non-photo aspect ratios) before it reaches the model. They use
only Pillow (already a runtime dependency) plus numpy (already an indirect
runtime dependency of torchvision) -- no new packages, no measurable memory
increase.

**These checks never prove an image IS a retinal fundus photo, clinically
adequate, or free of disease.** They are a coarse "obviously unsuitable"
filter only. Absence of a rejection is not evidence of suitability.

Every threshold is deliberately conservative and env-overridable: false
rejection of a genuine (if imperfect) fundus photo is the failure mode to
avoid, not the one to optimize against.
"""

import os

import numpy as np
from PIL import Image, ImageStat

MIN_ASPECT_RATIO = float(os.getenv("MIN_ASPECT_RATIO", "0.33"))  # ~1:3
MAX_ASPECT_RATIO = float(os.getenv("MAX_ASPECT_RATIO", "3.0"))  # ~3:1
MIN_MEAN_BRIGHTNESS = float(os.getenv("MIN_MEAN_BRIGHTNESS", "8"))  # near-black frame
MAX_MEAN_BRIGHTNESS = float(os.getenv("MAX_MEAN_BRIGHTNESS", "247"))  # blown-out frame
MIN_BLUR_VARIANCE = float(os.getenv("MIN_BLUR_VARIANCE", "15"))  # Laplacian-variance floor
# The blur check downsamples before computing a float64 Laplacian array, so
# its memory cost is bounded independent of the input image's resolution
# (e.g. an ungated 40-megapixel image would otherwise cost ~320MB for that
# one array alone -- see main.py's MAX_IMAGE_PIXELS comment for the same
# concern applied to the raw RGB decode). Blur is a low-frequency-enough
# signal that downsampling first doesn't meaningfully hurt detection.
_BLUR_CHECK_MAX_DIMENSION = int(os.getenv("BLUR_CHECK_MAX_DIMENSION", "800"))

# The circular-field/color-structure check is the least reliable of these
# heuristics (fundus photos vary a lot in framing/zoom) and is the most
# likely to false-reject a genuine photo, so it defaults OFF. Flip on only
# with real fundus samples on hand to validate the threshold first.
ENABLE_FUNDUS_SHAPE_CHECK = os.getenv("ENABLE_FUNDUS_SHAPE_CHECK", "false").strip().lower() == "true"
MIN_FUNDUS_COVERAGE = float(os.getenv("MIN_FUNDUS_COVERAGE", "0.08"))


class ImageSuitabilityError(Exception):
    """Raised when an image fails a suitability heuristic.

    `code` is a stable, machine-readable identifier the API returns
    alongside `message` so the Flutter client can localize its own copy
    instead of displaying the (English-only) backend message directly.
    """

    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(message)


def check_aspect_ratio(image: Image.Image) -> None:
    width, height = image.size
    ratio = width / height
    if ratio < MIN_ASPECT_RATIO or ratio > MAX_ASPECT_RATIO:
        raise ImageSuitabilityError(
            "bad_aspect_ratio",
            "This image's shape doesn't look like a photo. Please retake the photo.",
        )


def _laplacian_variance(grayscale: Image.Image) -> float:
    """A standard, cheap blur metric: variance of a Laplacian edge response.

    Low variance means few sharp edges anywhere in the frame, characteristic
    of an out-of-focus or motion-blurred photo. Computed directly with numpy
    (already an indirect runtime dependency via torchvision, see the module
    docstring) rather than PIL's ImageFilter.Kernel, which leaves the
    outermost 1px border uncomputed (copied verbatim from the source) --
    for a small or near-flat image that border ring can dominate the
    variance and mask genuine blur. Edge-replicated padding here ensures
    every pixel gets a real 3x3 neighborhood.
    """
    width, height = grayscale.size
    longest_side = max(width, height)
    if longest_side > _BLUR_CHECK_MAX_DIMENSION:
        scale = _BLUR_CHECK_MAX_DIMENSION / longest_side
        grayscale = grayscale.resize(
            (max(1, round(width * scale)), max(1, round(height * scale))),
            resample=Image.Resampling.BILINEAR,
        )

    array = np.asarray(grayscale, dtype=np.float64)
    padded = np.pad(array, 1, mode="edge")
    laplacian = (
        padded[0:-2, 1:-1]
        + padded[2:, 1:-1]
        + padded[1:-1, 0:-2]
        + padded[1:-1, 2:]
        - 4 * padded[1:-1, 1:-1]
    )
    return float(laplacian.var())


def check_exposure_and_blur(image: Image.Image) -> None:
    grayscale = image.convert("L")
    mean_brightness = ImageStat.Stat(grayscale).mean[0]

    if mean_brightness < MIN_MEAN_BRIGHTNESS:
        raise ImageSuitabilityError(
            "too_dark",
            "This photo looks too dark to analyze. Please retake it in better lighting.",
        )
    if mean_brightness > MAX_MEAN_BRIGHTNESS:
        raise ImageSuitabilityError(
            "too_bright",
            "This photo looks overexposed to analyze. Please retake the photo.",
        )

    if _laplacian_variance(grayscale) < MIN_BLUR_VARIANCE:
        raise ImageSuitabilityError(
            "too_blurry",
            "This photo looks too blurry to analyze. Please hold the camera steady and retake it.",
        )


def check_fundus_like_structure(image: Image.Image) -> None:
    """Optional, uncertain heuristic -- disabled by default (see module docstring)."""
    if not ENABLE_FUNDUS_SHAPE_CHECK:
        return

    grayscale = image.convert("L")
    histogram = grayscale.histogram()
    total = sum(histogram)
    if total == 0:
        return
    # Crude coverage estimate: fraction of pixels brighter than a mid
    # threshold, i.e. plausibly part of a lit fundus field rather than a
    # dark surround/vignette or an otherwise flat/empty frame.
    bright_pixels = sum(histogram[80:])
    coverage = bright_pixels / total
    if coverage < MIN_FUNDUS_COVERAGE:
        raise ImageSuitabilityError(
            "not_fundus_like",
            "This doesn't look like a retinal fundus photo. Please capture a fundus image.",
        )


def check_image_suitability(image: Image.Image) -> None:
    """Run all suitability heuristics; raises ImageSuitabilityError on the first failure."""
    check_aspect_ratio(image)
    check_exposure_and_blur(image)
    check_fundus_like_structure(image)
