"""
BasirahAI inference backend.

One real job: accept an uploaded retinal fundus photo, validate it, run it
through the pretrained diabetic retinopathy model, and return a screening
result. No database, no auth, no state — patient records and screening
history live in Supabase and are written directly by the Flutter app after
it receives this endpoint's response. See docs/ARCHITECTURE.md (and the
project plan) for the full picture.

This is a screening/decision-support signal, not a medical diagnosis. See
docs/MEDICAL_SAFETY.md for the wording contract the Flutter app follows
when presenting this endpoint's output to a user.
"""

import asyncio
import io
import logging
import os
import tempfile
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, UnidentifiedImageError

from . import fundus_gate, model
from .image_checks import ImageSuitabilityError, check_image_suitability

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("basirah")

MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB
MIN_IMAGE_DIMENSION = 64  # reject implausibly tiny "images"
# Decompression-bomb guard. Deliberately well below a high-end phone's raw
# sensor resolution (e.g. 108MP) -- decoding to RGB costs ~3 bytes/pixel, so
# a 100MP cap would let a single request's decode alone cost ~300MB against
# a container that measures ~483MB baseline RSS on Railway's ~1GB trial
# (dev/plan.md/HANDOFF.md's hosting history) and would blow well past
# Render's 512MB free tier, the documented fallback host (backend/README.md)
# -- so 40MP (~120MB worst-case decode) was chosen to leave real headroom on
# both, while still comfortably covering ordinary phone camera output (many
# high-megapixel sensors pixel-bin down to a much lower default output
# resolution in practice). Tune via env var if real-device testing shows
# genuine photos being rejected.
MAX_IMAGE_PIXELS = int(os.getenv("MAX_IMAGE_PIXELS", str(40_000_000)))
_UPLOAD_CHUNK_BYTES = 1024 * 1024  # 1 MB

# Bounds concurrent CPU-heavy inference work on a single shared vCPU so a
# burst of simultaneous requests can't oversubscribe the process's limited
# RAM/CPU. No queueing: a request arriving while at capacity is rejected
# immediately (503) rather than piling up. Cheap validation-only rejections
# (empty/oversized/corrupt/unsuitable image) never need a slot.
MAX_CONCURRENT_INFERENCE = int(os.getenv("MAX_CONCURRENT_INFERENCE", "1"))
_active_inferences = 0
_inference_lock = asyncio.Lock()


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Loading pretrained DR model (%s)...", model.MODEL_REPO_ID)
    model.load_model()
    logger.info("Model loaded.")
    logger.info("Loading fundus-content pre-filter...")
    fundus_gate.load_model()
    logger.info("Fundus-content pre-filter loaded.")
    yield


app = FastAPI(title="BasirahAI Inference API", lifespan=lifespan)

# Permissive during development; the mobile app doesn't rely on browser CORS
# the way a web frontend would, but this avoids losing time to a non-issue
# while building. Tighten before the final demo if there's time (see
# docs/ML_PLAN.md / dev/plan.md Day 6).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model_loaded": model.is_model_loaded(),
        "fundus_gate_loaded": fundus_gate.is_model_loaded(),
    }


async def _read_limited(upload: UploadFile, max_bytes: int) -> bytes:
    """Reject an oversized upload as soon as the limit is crossed, instead of
    reading the whole body to completion first."""
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = await upload.read(_UPLOAD_CHUNK_BYTES)
        if not chunk:
            break
        total += len(chunk)
        if total > max_bytes:
            raise HTTPException(
                status_code=413,
                detail=f"Image is too large (max {max_bytes // (1024 * 1024)} MB).",
            )
        chunks.append(chunk)
    return b"".join(chunks)


async def _reserve_inference_slot() -> bool:
    global _active_inferences
    async with _inference_lock:
        if _active_inferences >= MAX_CONCURRENT_INFERENCE:
            return False
        _active_inferences += 1
        return True


async def _release_inference_slot() -> None:
    global _active_inferences
    async with _inference_lock:
        _active_inferences -= 1


@app.post("/screen")
async def screen(image: UploadFile = File(...)):
    raw_bytes = await _read_limited(image, MAX_UPLOAD_BYTES)

    if len(raw_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    try:
        probe_image = Image.open(io.BytesIO(raw_bytes))
        width, height = probe_image.size
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="This doesn't look like a valid image file.")
    except Exception:
        raise HTTPException(status_code=400, detail="Could not read this image file.")

    # Check declared dimensions (header-only, no pixel decode yet) before
    # doing any heavier work, so a decompression-bomb-style file is rejected
    # before verify()/decode ever touches its pixel data.
    if width < MIN_IMAGE_DIMENSION or height < MIN_IMAGE_DIMENSION:
        raise HTTPException(
            status_code=400,
            detail="Image resolution is too small to analyze. Please retake the photo.",
        )
    if width * height > MAX_IMAGE_PIXELS:
        raise HTTPException(
            status_code=400,
            detail=f"Image resolution is too large to analyze (max {MAX_IMAGE_PIXELS // 1_000_000} MP). Please retake the photo at a lower resolution.",
        )

    try:
        probe_image.verify()
        # verify() invalidates the file pointer/object for further use, so
        # re-open before actually using it.
        pil_image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="This doesn't look like a valid image file.")
    except Exception:
        raise HTTPException(status_code=400, detail="Could not read this image file.")

    try:
        quality_warnings = check_image_suitability(pil_image)
    except ImageSuitabilityError as exc:
        raise HTTPException(status_code=400, detail={"code": exc.code, "message": exc.message})

    # Content check: aspect-ratio/exposure/blur above only ever validated
    # image *quality*, never whether the image is a fundus photo at all --
    # a real bug (an unrelated photo returning a confident, wrong DR result)
    # showed this gap directly. See app/fundus_gate.py and docs/FUNDUS_GATE.md.
    try:
        content_warning = fundus_gate.check_fundus_content(pil_image)
    except ImageSuitabilityError as exc:
        raise HTTPException(status_code=400, detail={"code": exc.code, "message": exc.message})
    if content_warning is not None:
        quality_warnings.append(content_warning)

    if not await _reserve_inference_slot():
        raise HTTPException(
            status_code=503,
            detail="The server is busy processing another screening. Please try again in a moment.",
        )

    # delete=False + manual cleanup: NamedTemporaryFile(delete=True) holds an
    # exclusive lock on Windows that a second open() (from PIL.save or
    # fastai's predict) can't share, raising PermissionError. Closing it
    # first and deleting it ourselves works correctly on both Windows and
    # the Linux container we deploy to.
    tmp = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
    tmp_path = tmp.name
    tmp.close()
    try:
        pil_image.save(tmp_path, format="JPEG")
        result = model.predict(tmp_path)
    except Exception:
        logger.exception("Inference failed")
        raise HTTPException(status_code=500, detail="Screening failed on the server. Please try again.")
    finally:
        os.unlink(tmp_path)
        await _release_inference_slot()

    # Logged before any UI-facing conversion/wording is applied, so the raw
    # model signal is always recoverable independent of how the client later
    # displays it (see dev/HANDOFF.md's note on tracing raw outputs).
    logger.info(
        "Raw model output: raw_grade=%s (%s) referable=%s confidence=%.4f probs=%s",
        result["raw_grade"],
        result["raw_grade_label"],
        result["referable"],
        result["confidence"],
        result["class_probabilities"],
    )

    result["quality_warnings"] = [
        {"code": warning.code, "message": warning.message} for warning in quality_warnings
    ]
    return result
