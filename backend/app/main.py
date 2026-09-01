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

import io
import logging
import os
import tempfile
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, UnidentifiedImageError

from . import model

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("basirah")

MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB
MIN_IMAGE_DIMENSION = 64  # reject implausibly tiny "images"


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Loading pretrained DR model (%s)...", model.MODEL_REPO_ID)
    model.load_model()
    logger.info("Model loaded.")
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
    return {"status": "ok", "model_loaded": model.is_model_loaded()}


@app.post("/screen")
async def screen(image: UploadFile = File(...)):
    raw_bytes = await image.read()

    if len(raw_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")
    if len(raw_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Image is too large (max {MAX_UPLOAD_BYTES // (1024 * 1024)} MB).",
        )

    try:
        pil_image = Image.open(io.BytesIO(raw_bytes))
        pil_image.verify()
        # verify() invalidates the file pointer/object for further use, so
        # re-open before actually using it.
        pil_image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="This doesn't look like a valid image file.")
    except Exception:
        raise HTTPException(status_code=400, detail="Could not read this image file.")

    width, height = pil_image.size
    if width < MIN_IMAGE_DIMENSION or height < MIN_IMAGE_DIMENSION:
        raise HTTPException(
            status_code=400,
            detail="Image resolution is too small to analyze. Please retake the photo.",
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

    return result
