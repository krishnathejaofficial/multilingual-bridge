"""
Voice API - Handles ASR, TTS, and monologue voice queries
"""

import base64
import logging
from typing import Optional

from fastapi import APIRouter, UploadFile, File, HTTPException, Form
from fastapi.responses import Response

from app.services.asr_service import asr_service
from app.services.tts_service import tts_service
from app.services.translation_service import translation_service
from app.models.schemas import VoiceQueryResponse
from app.utils.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/transcribe")
async def transcribe_audio(
    audio: UploadFile = File(...),
    language_hint: Optional[str] = Form(None)
):
    """
    Transcribe uploaded audio file.
    Returns transcript and detected language.
    """
    try:
        audio_bytes = await audio.read()
        if len(audio_bytes) > settings.MAX_AUDIO_SIZE_MB * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Audio file too large (max 25MB)")

        transcript, detected_lang = await asr_service.transcribe(audio_bytes, language_hint)

        return {
            "transcript": transcript,
            "detected_language": detected_lang,
            "language_name": settings.LANGUAGE_NAMES.get(detected_lang, detected_lang)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/query", response_model=VoiceQueryResponse)
async def voice_query(
    audio: UploadFile = File(...),
    source_lang: Optional[str] = Form(None),
    target_lang: str = Form("en"),
    speed: str = Form("slow")
):
    """
    Complete voice query pipeline:
    1. Transcribe audio
    2. Detect language
    3. Translate to target language
    4. Generate TTS response
    """
    try:
        audio_bytes = await audio.read()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="No audio data received")

        # Step 1: Transcribe
        transcript, detected_lang = await asr_service.transcribe(audio_bytes, source_lang)

        if not transcript.strip():
            raise HTTPException(status_code=400, detail="Could not transcribe audio")

        # Step 2: Translate
        translated = await translation_service.translate(transcript, detected_lang, target_lang)

        # Step 3: TTS
        audio_response = await tts_service.synthesize(
            text=translated,
            language_code=target_lang,
            speed=speed
        )
        audio_b64 = base64.b64encode(audio_response).decode("utf-8")

        return VoiceQueryResponse(
            transcript=transcript,
            detected_lang=detected_lang,
            translated_text=translated,
            target_lang=target_lang,
            tts_audio_base64=audio_b64
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Voice query failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/tts-stream")
async def text_to_speech(
    text: str = Form(...),
    language_code: str = Form("en"),
    speed: str = Form("slow")
):
    """Generate and stream TTS audio."""
    try:
        if not text.strip():
            raise HTTPException(status_code=400, detail="Text cannot be empty")

        audio_bytes = await tts_service.synthesize(
            text=text,
            language_code=language_code,
            speed=speed
        )

        return Response(
            content=audio_bytes,
            media_type="audio/mpeg",
            headers={"Content-Disposition": "attachment; filename=tts.mp3"}
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
