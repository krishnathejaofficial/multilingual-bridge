"""
Two-Person Conversation API
Handles real-time back-and-forth translation between two speakers
"""

import base64
import logging
from typing import Optional

from fastapi import APIRouter, UploadFile, File, HTTPException, Form, WebSocket, WebSocketDisconnect
from app.services.asr_service import asr_service
from app.services.tts_service import tts_service
from app.services.translation_service import translation_service
from app.models.schemas import ConversationTurnResponse
from app.utils.config import settings
import json

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/turn", response_model=ConversationTurnResponse)
async def conversation_turn(
    speaker_id: int = Form(...),
    speaker_lang: str = Form(...),
    listener_lang: str = Form(...),
    speed: str = Form("slow"),
    audio: Optional[UploadFile] = File(None),
    text: Optional[str] = Form(None)
):
    """
    Process one speaker's turn in a two-person conversation.
    Transcribes their speech → translates → returns TTS for the listener.
    """
    if speaker_id not in [1, 2]:
        raise HTTPException(status_code=400, detail="speaker_id must be 1 or 2")

    try:
        # Get speaker's text
        speaker_text = ""
        if audio:
            audio_bytes = await audio.read()
            speaker_text, _ = await asr_service.transcribe(audio_bytes, speaker_lang)
        elif text:
            speaker_text = text
        else:
            raise HTTPException(status_code=400, detail="Provide audio or text")

        if not speaker_text.strip():
            raise HTTPException(status_code=400, detail="Could not understand speech")

        # Translate to listener's language
        translated = await translation_service.translate(
            speaker_text, speaker_lang, listener_lang
        )

        # Generate TTS in listener's language
        audio_bytes = await tts_service.synthesize(
            text=translated,
            language_code=listener_lang,
            speed=speed
        )
        audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")

        return ConversationTurnResponse(
            speaker_id=speaker_id,
            original_text=speaker_text,
            translated_text=translated,
            speaker_lang=speaker_lang,
            listener_lang=listener_lang,
            tts_audio_base64=audio_b64
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Conversation turn failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.websocket("/ws/{session_id}")
async def conversation_websocket(websocket: WebSocket, session_id: str):
    """
    WebSocket endpoint for real-time two-person conversation.
    Clients send JSON: {speaker_id, speaker_lang, listener_lang, audio_b64}
    Server responds with: {speaker_id, original, translated, audio_b64}
    """
    await websocket.accept()
    logger.info(f"Conversation WebSocket connected: {session_id}")

    try:
        while True:
            data = await websocket.receive_json()

            speaker_id = data.get("speaker_id", 1)
            speaker_lang = data.get("speaker_lang", "en")
            listener_lang = data.get("listener_lang", "hi")
            audio_b64 = data.get("audio_b64")
            text = data.get("text")
            speed = data.get("speed", "slow")

            try:
                # Process turn
                speaker_text = ""
                if audio_b64:
                    import base64
                    audio_bytes = base64.b64decode(audio_b64)
                    speaker_text, _ = await asr_service.transcribe(audio_bytes, speaker_lang)
                elif text:
                    speaker_text = text

                if not speaker_text:
                    await websocket.send_json({"error": "Could not transcribe audio"})
                    continue

                translated = await translation_service.translate(
                    speaker_text, speaker_lang, listener_lang
                )

                tts_bytes = await tts_service.synthesize(translated, listener_lang, speed)
                tts_b64 = base64.b64encode(tts_bytes).decode("utf-8")

                await websocket.send_json({
                    "speaker_id": speaker_id,
                    "original_text": speaker_text,
                    "translated_text": translated,
                    "speaker_lang": speaker_lang,
                    "listener_lang": listener_lang,
                    "tts_audio_base64": tts_b64
                })

            except Exception as e:
                logger.error(f"WS turn error: {e}")
                await websocket.send_json({"error": str(e)})

    except WebSocketDisconnect:
        logger.info(f"Conversation WS disconnected: {session_id}")
