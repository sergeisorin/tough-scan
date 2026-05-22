# Real-Device Capture Validation Notes

Use this template before changing capture/readiness thresholds. Record observations on an actual iPhone running iOS 26 or later. Do not paste full OCR text, document images, personal details, prompts, generated notes, or sensitive file paths into this file.

## Device And Build

- Device model:
- iOS version:
- App branch or commit:
- Lighting/location:
- Tester:
- Date:

## Sample Set Checklist

Capture at least one sample for each category before threshold tuning:

- [ ] Low light
- [ ] Glare or overexposed page
- [ ] Blur or shaky capture
- [ ] Faded or low-contrast print
- [ ] Small fonts
- [ ] Skewed or creased page
- [ ] Hebrew
- [ ] English
- [ ] Mixed-language page
- [ ] Table, form, or receipt

## Per-Sample Notes

Copy this section for each sample. Use short masked excerpts only when text content is necessary to explain OCR quality.

### Sample: `<category-name>`

- Document type:
- Capture conditions:
- Guidance shown:
- Ready-for-review timing:
- Weak or missing regions highlighted accurately:
- OCR usefulness:
- Structured recognition usefulness:
- Copy/export usefulness:
- AI-assisted review usefulness, if available:
- Debug logs checked for document content:
- Proposed threshold or scoring implication:
- Follow-up needed:

## Threshold Tuning Summary

Fill this out after all samples are reviewed:

- Thresholds that feel too strict:
- Thresholds that feel too lenient:
- Guidance messages that appeared too early:
- Guidance messages that appeared too late:
- Cases where the app became ready before text was usable:
- Cases where the app stayed blocked even though the result was usable:
- Recommended tuning PR scope:
