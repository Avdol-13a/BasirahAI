# Medical Safety — Basirah

**Core principle: Basirah never states a diagnosis, only a screening signal plus a referral recommendation.** No wording implies certainty, clinical validation, or that a doctor's judgment has been replaced. This document is the canonical source of truth for all user-facing safety copy — `app/lib/l10n/app_en.arb` and `app/lib/l10n/app_ur.arb` should match this exactly. If you change wording, change it here first.

## The four result categories

> **Updated for the cloud-inference architecture:** results now come from the FastAPI `/screen` endpoint's response — `{referable: bool, confidence: float, raw_grade: 0-4}` (see `docs/ML_PLAN.md`, `backend/app/model.py`) — instead of an on-device sigmoid output. The category logic below maps onto that response; the wording itself is unchanged.

| Situation | Trigger | English | Urdu |
|---|---|---|---|
| **Poor-quality / invalid image** | Backend rejects the upload before running the model. Two layers: (1) structural checks — corrupt file, wrong type, too small/too large (`backend/app/main.py`); (2) suitability checks added 2026-09-02 — bad aspect ratio, too dark, too bright, too blurry (`backend/app/image_checks.py`, Pillow/numpy only). Each returns a stable code the Flutter app maps to its own localized string (`ScreeningCaptureScreen._imageIssueMessage`) — see `docs/IMAGE_PIPELINE.md`. | e.g. too dark: "This photo looks too dark to analyze. Please retake it in better lighting." too blurry: "This photo looks too blurry to analyze. Please hold the camera steady and retake it." (exact current strings for every code live in `app/lib/l10n/app_en.arb`) | e.g. too dark: یہ تصویر تجزیے کے لیے بہت تاریک ہے۔ براہ کرم بہتر روشنی میں دوبارہ تصویر لیں۔ (exact current strings in `app/lib/l10n/app_ur.arb`) |
| **Non-Referable** | `referable: false` in the API response, and `confidence` at or above the low-confidence cutoff (see below) | "This screening did not find signs of diabetic retinopathy that need urgent treatment. This does not mean diabetic retinopathy is absent — milder changes are still possible. This is not a diagnosis. Regular eye check-ups are still recommended, especially if the patient has diabetes." | اس اسکریننگ میں ذیابیطس ریٹینوپیتھی کی ایسی علامت نہیں ملی جس کے لیے فوری علاج درکار ہو۔ اس کا مطلب یہ نہیں کہ ریٹینوپیتھی بالکل موجود نہیں — ہلکی تبدیلیاں پھر بھی ہو سکتی ہیں۔ یہ تشخیص نہیں ہے۔ آنکھوں کا باقاعدہ معائنہ اب بھی تجویز کیا جاتا ہے، خاص طور پر اگر مریض کو ذیابیطس ہو۔ |
| **Referable** | `referable: true` in the API response, and `confidence` at or above the low-confidence cutoff | "This screening found signs that should be checked by an eye-care professional. Please see an ophthalmologist as soon as you can. This is not a diagnosis — only a specialist can confirm what this means." | اس اسکریننگ میں ایسی علامات ملی ہیں جن کا ماہرِ امراضِ چشم سے معائنہ ضروری ہے۔ براہ کرم جلد از جلد کسی آنکھوں کے ڈاکٹر سے ملیں۔ یہ تشخیص نہیں ہے — صرف ایک ماہر ہی اس کی تصدیق کر سکتا ہے۔ |
| **Low-confidence / borderline** | `confidence` below a chosen cutoff (starting point: 0.6 — tune during Day 2's independent evaluation and record the final value here) regardless of the `referable` value | "This screening could not give a clear result. Please see an eye-care professional to be sure." | یہ اسکریننگ واضح نتیجہ نہیں دے سکی۔ براہ کرم یقینی بنانے کے لیے آنکھوں کے ماہر سے رجوع کریں۔ |
| **Soft/borderline-quality image (non-blocking warning)** | The image passed the suitability gate but scored between the blur gate's reject floor and its warn threshold (`quality_warnings` contains a `soft_focus` entry — see `docs/IMAGE_PIPELINE.md`); the screening still runs and a normal result category above still applies | Shown as an additional banner alongside whichever result category above applies: "This photo looked a bit soft. The result below may be less reliable — for best accuracy, consider retaking with a steadier hand and better focus." | یہ تصویر تھوڑی سی دھندلی تھی۔ نیچے دیا گیا نتیجہ کم قابلِ اعتماد ہو سکتا ہے — بہتر نتیجے کے لیے ہاتھ ساکت رکھ کر اور بہتر فوکس کے ساتھ دوبارہ تصویر لینے پر غور کریں۔ |

**Low-confidence cutoff used:** _fill in after Day 2's independent evaluation_

**2026-09-03 wording correction:** the Non-Referable copy previously read "No Urgent Concern Found" / "No signs of urgent concern were found in this screening" — accurate about urgency, but easy to misread as "no diabetic retinopathy." Non-Referable (grades 0-1) includes Mild NPDR (grade 1), which *is* diabetic retinopathy, just not at referable severity. The copy above now says explicitly that this result does not mean DR is absent. **"Non-Referable" must never be presented or read as equivalent to "No DR."**

## Standing disclaimer (shown on every result screen)

- **English:** "Basirah is a screening aid, not a diagnosis. It has not been clinically validated. Always follow up with a qualified eye-care professional."
- **Urdu:** بصیرت ایک اسکریننگ معاون ہے، تشخیص نہیں۔ اس کی طبی توثیق نہیں ہوئی۔ ہمیشہ ایک مستند ماہرِ امراضِ چشم سے رجوع کریں۔

## Cross-cutting rules for all safety copy (English and Urdu)

- Never use "diagnose," "confirmed," "you have [condition]," or state the confidence score as if it were a clinical probability of disease.
- Every result — including "Non-Referable" — ends with a consult-a-professional message. A clean result is never framed as "all clear forever."
- **The per-screening confidence score IS shown on the result screen** — this is a required product feature (unlike the earlier on-device-only plan, which deliberately hid it). Frame it as "how confident this specific screening result is," not as "the AI's overall accuracy" or a clinical probability of having the disease — those are different numbers and must not be conflated. The model's own overall accuracy (self-reported or ours) stays in `docs/EVALUATION_RESULTS.md`, not the per-result confidence shown in the app.
- Plain, everyday Urdu — avoid heavy Persian/Arabic medical loanwords ordinary users won't recognize.

## Translation review status

**These Urdu translations were drafted to be clear, simple, and medically cautious, but have not yet been reviewed by a native Urdu-speaking medical-literacy expert.** This review is a scheduled Day 6 task (see `dev/plan.md`), not optional polish.

- [ ] Native speaker reviewed all four result messages
- [ ] Native speaker reviewed the standing disclaimer
- [ ] Any wording changes made as a result, recorded below

### Review notes

_fill in after the Day 6 native-speaker review — what changed, and why_

## What must never appear in Basirah, in any language

- Any claim of clinical validation, regulatory clearance, or diagnostic capability.
- Any specific accuracy/sensitivity/specificity number in user-facing copy (engineering docs only).
- Any wording that could be read as replacing, rather than supplementing, a real eye exam.
