"""
Paste & Reply API - Core Feature
Handles the complete flow of understanding and replying to chat messages
"""

import base64
import logging
from typing import Optional

from fastapi import APIRouter, UploadFile, File, HTTPException, Form
from fastapi.responses import Response

from app.models.schemas import (
    PasteExplainRequest, PasteExplainResponse,
    PasteReplyRequest, PasteReplyResponse
)
from app.services.translation_service import translation_service
from app.services.tts_service import tts_service
from app.services.llm_service import llm_service
from app.utils.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/explain", response_model=PasteExplainResponse)
async def explain_pasted_message(request: PasteExplainRequest):
    """
    STEP 1 of Paste & Reply:
    1. Detect language of pasted text
    2. Normalize slang/abbreviations via LLM
    3. Explain in user's native language
    4. Analyze sentiment
    5. Generate TTS audio of the explanation
    """
    if not request.pasted_text.strip():
        raise HTTPException(status_code=400, detail="Pasted text cannot be empty")

    try:
        # Step 1: Detect source language
        logger.info(f"Detecting language of: {request.pasted_text[:50]}...")
        detected_lang = await translation_service.detect_language(request.pasted_text)
        lang_name = settings.LANGUAGE_NAMES.get(detected_lang, detected_lang.upper())

        # Step 2: Normalize (expand abbreviations, slang, emojis)
        logger.info("Normalizing chat message...")
        normalized_text = await llm_service.normalize_chat_message(request.pasted_text)

        # Step 3: Translate normalized text to user's native language
        user_lang_name = settings.LANGUAGE_NAMES.get(request.user_native_lang, "English")
        logger.info(f"Translating to {user_lang_name}...")

        if detected_lang != request.user_native_lang:
            translated = await translation_service.translate(
                normalized_text, detected_lang, request.user_native_lang
            )
        else:
            translated = normalized_text

        # Step 4: Generate simple explanation
        explanation = await llm_service.explain_message(normalized_text, user_lang_name)

        # Step 5: Get sentiment analysis
        sentiment = await llm_service.get_sentiment(normalized_text, user_lang_name)

        # Step 6: Generate TTS audio for the explanation
        explanation_text_for_speech = (
            f"This message is in {lang_name}. "
            f"It says: {translated}. "
            f"{sentiment}"
        )

        logger.info("Generating TTS audio...")
        audio_bytes = await tts_service.synthesize(
            text=explanation_text_for_speech,
            language_code=request.user_native_lang,
            speed=request.speed.value
        )
        audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")

        return PasteExplainResponse(
            original_text=request.pasted_text,
            normalized_text=normalized_text,
            detected_source_lang=detected_lang,
            detected_source_lang_name=lang_name,
            explanation_in_user_lang=f"{translated}\n\n{explanation}",
            sentiment=sentiment,
            tts_audio_base64=audio_b64
        )

    except Exception as e:
        logger.error(f"Explain failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Processing failed: {str(e)}")


@router.post("/reply", response_model=PasteReplyResponse)
async def generate_reply(
    pasted_text_context: str = Form(...),
    user_native_lang: str = Form(...),
    recipient_lang: str = Form(...),
    speed: str = Form("slow"),
    user_reply_audio: Optional[UploadFile] = File(None),
    user_reply_text: Optional[str] = Form(None)
):
    """
    STEP 2 of Paste & Reply:
    1. If audio provided: transcribe user's spoken reply (in native language)
    2. Translate reply to recipient's language
    3. Return translated text (ready to copy-paste) + TTS confirmation
    """
    from app.services.asr_service import asr_service

    user_reply_original = ""

    try:
        # Step 1: Get user's reply text
        if user_reply_audio:
            logger.info("Transcribing user's spoken reply...")
            audio_bytes = await user_reply_audio.read()
            if len(audio_bytes) > settings.MAX_AUDIO_SIZE_MB * 1024 * 1024:
                raise HTTPException(status_code=413, detail="Audio file too large")

            user_reply_original, _ = await asr_service.transcribe(
                audio_bytes, language_hint=user_native_lang
            )
        elif user_reply_text:
            user_reply_original = user_reply_text
        else:
            raise HTTPException(
                status_code=400,
                detail="Either audio file or text must be provided"
            )

        if not user_reply_original.strip():
            raise HTTPException(status_code=400, detail="Could not understand the reply")

        # Step 2: Translate reply to recipient's language
        logger.info(f"Translating reply from {user_native_lang} to {recipient_lang}...")
        translated_reply = await translation_service.translate(
            user_reply_original, user_native_lang, recipient_lang
        )

        # Step 3: Generate confirmation TTS in user's language
        recipient_lang_name = settings.LANGUAGE_NAMES.get(recipient_lang, recipient_lang)
        confirmation_text = (
            f"Your reply has been translated to {recipient_lang_name}. "
            f"Tap the copy button to copy it."
        )

        audio_bytes = await tts_service.synthesize(
            text=confirmation_text,
            language_code=user_native_lang,
            speed=speed
        )
        audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")

        return PasteReplyResponse(
            user_reply_original=user_reply_original,
            translated_reply=translated_reply,
            recipient_lang=recipient_lang,
            tts_audio_base64=audio_b64
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Reply generation failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Reply generation failed: {str(e)}")


@router.get("/languages")
async def get_supported_languages():
    """Return list of supported languages with display names."""
    return {
        "languages": [
            {"code": code, "name": name}
            for code, name in settings.LANGUAGE_NAMES.items()
        ]
    }


@router.post("/tts")
async def generate_tts(
    text: str = Form(...),
    language_code: str = Form("en"),
    speed: str = Form("slow")
):
    """Generate TTS audio for given text."""
    try:
        audio_bytes = await tts_service.synthesize(
            text=text,
            language_code=language_code,
            speed=speed
        )
        return Response(
            content=audio_bytes,
            media_type="audio/mpeg",
            headers={"Content-Disposition": "attachment; filename=speech.mp3"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
