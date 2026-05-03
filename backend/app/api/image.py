"""
Image & OCR API Router
Handles screenshot processing and visual question answering
"""

import base64
import logging
from typing import Optional

from fastapi import APIRouter, UploadFile, File, HTTPException, Form
from app.services.ocr_service import ocr_service
from app.services.translation_service import translation_service
from app.services.tts_service import tts_service
from app.models.schemas import ImageOCRResponse
from app.utils.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/screenshot", response_model=ImageOCRResponse)
async def process_screenshot(
    image: UploadFile = File(...),
    user_native_lang: str = Form("en"),
    question: Optional[str] = Form(None),
    speed: str = Form("slow")
):
    """
    Process a screenshot:
    1. Extract text with OCR
    2. Detect language
    3. Translate to user's language
    4. If question asked, answer it using VLM
    5. Return text + TTS audio
    """
    try:
        image_bytes = await image.read()
        if len(image_bytes) > settings.MAX_IMAGE_SIZE_MB * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Image too large (max 10MB)")

        # Process image
        logger.info("Processing screenshot with OCR...")
        result = await ocr_service.process_screenshot(image_bytes, question)

        extracted_text = result.get("extracted_text", "")
        answer = result.get("answer", "")

        if not extracted_text and not answer:
            return ImageOCRResponse(
                extracted_text="",
                answer="I could not find any readable text in this image.",
                detected_language=None
            )

        # Detect language of extracted text
        detected_lang = "en"
        if extracted_text:
            detected_lang = await translation_service.detect_language(extracted_text)

        # Translate if needed
        response_text = answer or extracted_text
        if detected_lang != user_native_lang:
            response_text = await translation_service.translate(
                response_text, detected_lang, user_native_lang
            )

        return ImageOCRResponse(
            extracted_text=extracted_text,
            answer=response_text,
            detected_language=detected_lang
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Screenshot processing failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
