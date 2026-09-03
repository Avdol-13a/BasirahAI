FROM python:3.11-slim AS model-builder

WORKDIR /build

COPY requirements-build.txt export_model.py export_fundus_backbone.py ./
RUN pip install --no-cache-dir torch==2.6.0 torchvision==0.21.0 \
        --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir -r requirements-build.txt \
    && python export_model.py \
    && python export_fundus_backbone.py


FROM python:3.11-slim

WORKDIR /code

COPY requirements.txt .
RUN pip install --no-cache-dir torch==2.6.0 torchvision==0.21.0 \
        --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY --from=model-builder /model /model

# Hugging Face Spaces (Docker SDK) expects the app to listen on 7860 by
# default. If deployed elsewhere (e.g. the Alibaba Cloud ECS fallback —
# see docs/ML_PLAN.md), this port can be remapped at the container-run
# level without changing this file.
EXPOSE 7860

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-7860}"]
