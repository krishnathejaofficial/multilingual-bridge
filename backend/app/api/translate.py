"""
Translation API Router
"""

import logging
from fastapi import APIRouter, HTTPException
from app.models.schemas import (
    TranslateRequest, TranslateResponse,
    DetectLanguageRequest, DetectLanguageResponse
)
from app.services.translation_service import translation_service
from app.utils.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/translate", response_model=TranslateResponse)
async def translate_text(request: TranslateRequest):
    """Translate text between languages."""
    try:
        source = request.source_lang
        if not source:
            source = await translation_service.detect_language(request.text)

        translated = await translation_service.translate(
            request.text, source, request.target_lang
        )

        return TranslateResponse(
            original_text=request.text,
            translated_text=translated,
            detected_source_lang=source,
            target_lang=request.target_lang
        )
    except Exception as e:
        logger.error(f"Translation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/detect-language", response_model=DetectLanguageResponse)
async def detect_language(request: DetectLanguageRequest):
    """Detect the language of provided text."""
    try:
        lang_code = await translation_service.detect_language(request.text)
        lang_name = settings.LANGUAGE_NAMES.get(lang_code, lang_code.upper())
        return DetectLanguageResponse(language_code=lang_code, language_name=lang_name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/languages")
async def get_languages():
    """Return all supported languages."""
    return {
        "languages": [
            {"code": k, "name": v}
            for k, v in settings.LANGUAGE_NAMES.items()
        ]
    }
