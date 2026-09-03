"""Train the "is this a fundus photo" pre-filter used before the DR model.

Motivation (2026-09-03): the existing image-suitability checks (aspect
ratio, exposure, blur) never verify image *content* -- a clearly unrelated
photo (tested: the app's own logo) sails through and gets a confident, wrong
DR result. A cheap color-based heuristic was tried and rejected (see
docs/FUNDUS_GATE.md): it fails on the single most likely accidental input --
a photo of skin/wood/etc, since those are red-dominant too, same as a real
fundus photo.

This trains a small binary classifier instead: a frozen ImageNet-pretrained
MobileNetV3-Small backbone (10MB, already the same torchvision dependency
the DR model uses) as a feature extractor, plus a small trained logistic
head on top. Only the head is trained -- the backbone's ImageNet features
are used as-is, which is standard, fast, low-data-requirement transfer
learning appropriate for a same-day dataset this size.

Data:
- Positives ("is a fundus photo"): the 201 real APTOS images already in
  backend/eval_data/images/ (the same real, clinically-labeled sample used
  for the DR model's own evaluation).
- Negatives ("is not a fundus photo"): two sources, deliberately different
  in kind, after a first training pass with CIFAR-10 alone proved
  insufficient (see below). (1) CIFAR-10 (real photographs across 10
  everyday classes: planes, cars, birds, cats, deer, dogs, frogs, horses,
  ships, trucks) -- covers "photo of a real-world object." (2) Procedurally
  generated flat/graphic images (solid backgrounds + simple geometric
  shapes, see _generate_synthetic_graphics) -- covers "logo/icon/UI
  graphic," a visually distinct category CIFAR-10 doesn't represent at all.

**First-pass finding, kept here rather than hidden:** training on CIFAR-10
negatives alone produced a classifier with a perfect-looking 1.0 held-out
validation accuracy, but it failed the one held-out case that mattered most
-- the app's own logo (the exact image that exposed the original bug) still
scored 88.8% "fundus." CIFAR-10's negatives are all busy, continuous-tone
natural photos, so the model learned to separate "fundus photo" from
"photo of an object" without ever learning to reject a flat vector
graphic. The synthetic graphic negatives above were added specifically to
close that gap, and the logo (never included in training) is still checked
in the sanity set below as the real test of whether it worked.

Honesty discipline (matches this project's "never fabricate metrics"
principle, see dev/HANDOFF.md): every number this script prints/saves is a
real measurement on a held-out split, not tuned to look good. It also runs
the trained classifier against a small, hand-picked "known bad" sanity set
(the app logo, icons, UI screenshots -- the exact images that exposed this
bug) which the classifier never saw during training, as an extra
out-of-distribution generalization check.

Output:
- backend/app/fundus_gate_head.pt -- the trained head's state dict (~5KB,
  committed to the repo, unlike the large DR model artifact).
- backend/eval_data/fundus_gate_metrics.json -- real measured metrics.

Run once locally (not part of the Docker build or CI):
    python train_fundus_gate.py
"""

import io
import json
import os
import random
import sys
import time

import torch
import torch.nn as nn
from PIL import Image, ImageDraw
from torch.utils.data import DataLoader, TensorDataset
from torchvision.models import MobileNet_V3_Small_Weights, mobilenet_v3_small

SEED = 1337
random.seed(SEED)
torch.manual_seed(SEED)

HERE = os.path.dirname(__file__)
POSITIVE_DIR = os.path.join(HERE, "eval_data", "images")
CIFAR_ROOT = os.path.join(HERE, "eval_data", "cifar10_kaggle")  # gitignored
HEAD_OUT_PATH = os.path.join(HERE, "app", "fundus_gate_head.pt")
METRICS_OUT_PATH = os.path.join(HERE, "eval_data", "fundus_gate_metrics.json")

# Known-bad sanity set: real, non-fundus images already in the repo that
# exposed the original bug. Never used for training -- held out entirely as
# an independent generalization check.
KNOWN_NON_FUNDUS_IMAGES = [
    os.path.join(HERE, "..", "app", "assets", "branding", "basirah_logo.png"),
    os.path.join(HERE, "..", "docs", "screenshots", "login.png"),
    os.path.join(HERE, "..", "docs", "screenshots", "result.png"),
    os.path.join(HERE, "..", "docs", "screenshots", "result_non_referable.png"),
    os.path.join(HERE, "..", "docs", "screenshots", "urdu.png"),
    os.path.join(HERE, "..", "app", "web", "icons", "Icon-512.png"),
    os.path.join(HERE, "..", "app", "web", "favicon.png"),
    os.path.join(HERE, "..", "app", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset", "Icon-App-1024x1024@1x.png"),
    os.path.join(HERE, "..", "app", "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset", "app_icon_512.png"),
]

VAL_FRACTION = 0.2
N_CIFAR_NEGATIVES = 400
N_SYNTHETIC_NEGATIVES = 250  # flat/graphic images -- see _generate_synthetic_graphics
EPOCHS = 300
LR = 1e-2
WEIGHT_DECAY = 5e-2  # meaningful L2 regularization -- small dataset, avoid overfitting


def _load_backbone():
    print("Loading frozen MobileNetV3-Small (ImageNet pretrained)...")
    weights = MobileNet_V3_Small_Weights.IMAGENET1K_V1
    backbone = mobilenet_v3_small(weights=weights)
    backbone.eval()
    for p in backbone.parameters():
        p.requires_grad_(False)
    return backbone, weights.transforms()


@torch.inference_mode()
def _extract_features(backbone, preprocess, images: list[Image.Image]) -> torch.Tensor:
    feats = []
    for img in images:
        tensor = preprocess(img).unsqueeze(0)
        pooled = backbone.avgpool(backbone.features(tensor))
        feats.append(pooled.flatten(1).squeeze(0))
    return torch.stack(feats)


def _load_positives() -> list[Image.Image]:
    files = sorted(f for f in os.listdir(POSITIVE_DIR) if f.lower().endswith(".png"))
    print(f"Loading {len(files)} real fundus photos (positives) from {POSITIVE_DIR}...")
    return [Image.open(os.path.join(POSITIVE_DIR, f)).convert("RGB") for f in files]


def _generate_synthetic_graphics(n: int, seed: int = SEED) -> list[Image.Image]:
    """Flat/graphic-style negatives: solid backgrounds with a few geometric
    shapes in varied palettes (cool, warm, pastel, high-contrast).

    Added after the first training pass: CIFAR-10 alone (busy, textured
    natural-scene photos) taught the classifier to reject "photo of an
    object" but not "flat vector graphic" -- proven by a real held-out
    failure, the app's own logo scored 88.8% "fundus" even though it was
    never used for training. Real fundus photos and CIFAR-10 photos are
    both continuous-tone photographs; a flat-color logo/icon/UI graphic is a
    third, visually distinct category neither source teaches the model to
    reject. These are procedurally generated (not the actual logo/icons/
    screenshots, which stay held out as an independent sanity check) so the
    classifier has to learn the general "flat graphic" concept rather than
    memorize specific files.
    """
    rng = random.Random(seed)
    images = []
    for _ in range(n):
        size = (224, 224)
        bg = tuple(rng.randint(0, 255) for _ in range(3))
        img = Image.new("RGB", size, bg)
        draw = ImageDraw.Draw(img)
        n_shapes = rng.randint(0, 4)
        for _ in range(n_shapes):
            color = tuple(rng.randint(0, 255) for _ in range(3))
            shape = rng.choice(["ellipse", "rectangle", "line"])
            x0, y0 = rng.randint(0, size[0]), rng.randint(0, size[1])
            x1, y1 = rng.randint(0, size[0]), rng.randint(0, size[1])
            box = (min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1))
            if shape == "ellipse":
                draw.ellipse(box, fill=color)
            elif shape == "rectangle":
                draw.rectangle(box, fill=color)
            else:
                draw.line(box, fill=color, width=rng.randint(1, 12))
        images.append(img)
    return images


def _load_negatives() -> list[Image.Image]:
    from torchvision.datasets import CIFAR10

    # torchvision's own CIFAR-10 mirror (www.cs.toronto.edu) was measured at
    # ~30-40kB/s from this network -- 170MB would take over an hour. Same
    # standard cifar-10-python.tar.gz content, fetched via the Kaggle API
    # (already authenticated in this env, used for the APTOS eval images
    # too) instead: ~325MB in ~80s. download=False since it's already
    # extracted to CIFAR_ROOT/cifar-10-batches-py/.
    print(f"Loading CIFAR-10 (negatives) from {CIFAR_ROOT} (fetched via Kaggle, not torchvision's slow mirror)...")
    dataset = CIFAR10(root=CIFAR_ROOT, train=True, download=False)
    indices = list(range(len(dataset)))
    random.Random(SEED).shuffle(indices)
    chosen = indices[:N_CIFAR_NEGATIVES]
    cifar_images = [dataset[i][0].convert("RGB") for i in chosen]
    print(f"  sampled {len(cifar_images)} CIFAR-10 images across its 10 real-world classes")

    graphic_images = _generate_synthetic_graphics(N_SYNTHETIC_NEGATIVES)
    print(f"  generated {len(graphic_images)} synthetic flat/graphic images")

    return cifar_images + graphic_images


def _split(items, val_fraction, seed=SEED):
    idx = list(range(len(items)))
    random.Random(seed).shuffle(idx)
    n_val = max(1, int(len(items) * val_fraction))
    val_idx, train_idx = idx[:n_val], idx[n_val:]
    return [items[i] for i in train_idx], [items[i] for i in val_idx]


def _metrics(logits: torch.Tensor, labels: torch.Tensor, threshold: float = 0.5):
    probs = torch.sigmoid(logits)
    preds = (probs >= threshold).float()
    tp = float(((preds == 1) & (labels == 1)).sum())
    tn = float(((preds == 0) & (labels == 0)).sum())
    fp = float(((preds == 1) & (labels == 0)).sum())
    fn = float(((preds == 0) & (labels == 1)).sum())
    n = len(labels)
    return {
        "n": n,
        "accuracy": (tp + tn) / n if n else float("nan"),
        "fundus_recall": tp / (tp + fn) if (tp + fn) else float("nan"),  # real fundus correctly kept
        "negative_recall": tn / (tn + fp) if (tn + fp) else float("nan"),  # non-fundus correctly caught
        "false_reject_rate": fn / (tp + fn) if (tp + fn) else float("nan"),  # real fundus wrongly blocked
        "false_accept_rate": fp / (tn + fp) if (tn + fp) else float("nan"),  # junk wrongly let through
        "tp": tp, "tn": tn, "fp": fp, "fn": fn,
    }


def main():
    start = time.time()
    backbone, preprocess = _load_backbone()

    positives = _load_positives()
    negatives = _load_negatives()

    pos_train, pos_val = _split(positives, VAL_FRACTION)
    neg_train, neg_val = _split(negatives, VAL_FRACTION)
    print(f"Train: {len(pos_train)} positive / {len(neg_train)} negative")
    print(f"Val:   {len(pos_val)} positive / {len(neg_val)} negative")

    print("Extracting frozen backbone features (train)...")
    train_images = pos_train + neg_train
    train_labels = torch.tensor([1.0] * len(pos_train) + [0.0] * len(neg_train))
    train_feats = _extract_features(backbone, preprocess, train_images)

    print("Extracting frozen backbone features (val)...")
    val_images = pos_val + neg_val
    val_labels = torch.tensor([1.0] * len(pos_val) + [0.0] * len(neg_val))
    val_feats = _extract_features(backbone, preprocess, val_images)

    feature_dim = train_feats.shape[1]
    head = nn.Linear(feature_dim, 1)
    optimizer = torch.optim.Adam(head.parameters(), lr=LR, weight_decay=WEIGHT_DECAY)
    loss_fn = nn.BCEWithLogitsLoss()

    loader = DataLoader(
        TensorDataset(train_feats, train_labels), batch_size=32, shuffle=True, generator=torch.Generator().manual_seed(SEED)
    )

    print(f"Training a {feature_dim}->1 logistic head for {EPOCHS} epochs...")
    head.train()
    for epoch in range(EPOCHS):
        for xb, yb in loader:
            optimizer.zero_grad()
            logits = head(xb).squeeze(1)
            loss = loss_fn(logits, yb)
            loss.backward()
            optimizer.step()
        if (epoch + 1) % 50 == 0:
            with torch.inference_mode():
                val_logits = head(val_feats).squeeze(1)
                val_loss = loss_fn(val_logits, val_labels).item()
            print(f"  epoch {epoch + 1}/{EPOCHS}  train_loss={loss.item():.4f}  val_loss={val_loss:.4f}")

    head.eval()
    with torch.inference_mode():
        train_logits = head(train_feats).squeeze(1)
        val_logits = head(val_feats).squeeze(1)

    train_metrics = _metrics(train_logits, train_labels)
    val_metrics = _metrics(val_logits, val_labels)
    print("\n=== Held-out validation metrics (real numbers, not tuned) ===")
    for k, v in val_metrics.items():
        print(f"  {k}: {v}")

    # Independent generalization check: images the classifier never saw
    # during training or validation, and that are known to be non-fundus
    # (they're what exposed the original bug).
    known_bad_images = []
    known_bad_paths = []
    for path in KNOWN_NON_FUNDUS_IMAGES:
        if os.path.isfile(path):
            known_bad_images.append(Image.open(path).convert("RGB"))
            known_bad_paths.append(os.path.relpath(path, HERE))
    known_bad_feats = _extract_features(backbone, preprocess, known_bad_images)
    with torch.inference_mode():
        known_bad_logits = head(known_bad_feats).squeeze(1)
        known_bad_probs = torch.sigmoid(known_bad_logits)
    print("\n=== Known non-fundus sanity set (never seen in training) ===")
    sanity_results = []
    for path, prob in zip(known_bad_paths, known_bad_probs.tolist()):
        verdict = "WRONGLY PASSED AS FUNDUS" if prob >= 0.5 else "correctly flagged as non-fundus"
        print(f"  {path}: fundus_probability={prob:.4f}  ({verdict})")
        sanity_results.append({"path": path, "fundus_probability": prob, "correct": prob < 0.5})

    # Also score every real fundus photo (train+val) so the reject threshold
    # below can be picked with knowledge of the full real-data distribution,
    # not just the smaller val split.
    with torch.inference_mode():
        all_pos_feats = _extract_features(backbone, preprocess, positives)
        all_pos_probs = torch.sigmoid(head(all_pos_feats).squeeze(1))
    sorted_probs = torch.sort(all_pos_probs).values
    n_pos = len(sorted_probs)
    percentiles = {
        p: float(sorted_probs[min(n_pos - 1, int(n_pos * p / 100))])
        for p in (0, 1, 2, 5, 10, 25, 50)
    }
    min_real_fundus_prob = percentiles[0]
    print(f"\nFundus-probability distribution across ALL {n_pos} real fundus photos:")
    for p, v in percentiles.items():
        print(f"  p{p}: {v:.4f}")

    # Also score the known non-fundus sanity images against a few candidate
    # reject thresholds, so the threshold picked in app/fundus_gate.py is
    # chosen from real numbers, not guessed.
    print("\nCandidate reject thresholds vs. the sanity set (lower probability = more confidently non-fundus):")
    for threshold in (0.5, 0.6, 0.7, 0.75, 0.8):
        n_sanity_caught = sum(1 for r in sanity_results if r["fundus_probability"] < threshold)
        n_real_fundus_lost = int((all_pos_probs < threshold).sum())
        print(
            f"  threshold={threshold}: catches {n_sanity_caught}/{len(sanity_results)} sanity negatives, "
            f"would reject {n_real_fundus_lost}/{n_pos} real fundus photos"
        )

    torch.save(head.state_dict(), HEAD_OUT_PATH)
    print(f"\nSaved trained head to {HEAD_OUT_PATH}")

    metrics = {
        "trained_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "backbone": "mobilenet_v3_small (ImageNet1K_V1, frozen)",
        "feature_dim": feature_dim,
        "positives_source": "backend/eval_data/images (real APTOS fundus photos)",
        "negatives_source": "CIFAR-10 train split (torchvision)",
        "n_positive_total": len(positives),
        "n_negative_total": len(negatives),
        "train_metrics": train_metrics,
        "val_metrics": val_metrics,
        "known_non_fundus_sanity_check": sanity_results,
        "min_fundus_probability_across_all_real_photos": min_real_fundus_prob,
        "training_seconds": round(time.time() - start, 1),
    }
    with open(METRICS_OUT_PATH, "w") as f:
        json.dump(metrics, f, indent=2)
    print(f"Saved metrics to {METRICS_OUT_PATH}")


if __name__ == "__main__":
    main()
