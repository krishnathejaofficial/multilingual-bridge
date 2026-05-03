"""
Automatic Speech Recognition (ASR) Service
Primary: NVIDIA Riva ASR
Fallback: OpenAI Whisper (via faster-whisper)
"""

import io
import logging
import tempfile
import os
from typing import Optional, Tuple

import httpx

from app.utils.config import settings

logger = logging.getLogger(__name__)


class ASRService:
    """
    Speech-to-text service with NVIDIA Riva as primary
    and faster-whisper as fallback.
    """

    def __init__(self):
        self._whisper_model = None

    def _get_whisper_model(self):
        """Lazy load Whisper model (only when needed as fallback)."""
        if self._whisper_model is None:
            try:
                from faster_whisper import WhisperModel
                logger.info(f"Loading Whisper model: {settings.WHISPER_MODEL}")
                self._whisper_model = WhisperModel(
                    settings.WHISPER_MODEL,
                    device="cpu",
                    compute_type="int8"
                )
                logger.info("Whisper model loaded successfully")
            except ImportError:
                logger.warning("faster-whisper not installed. Trying openai-whisper...")
                try:
                    import whisper
                    self._whisper_model = whisper.load_model(settings.WHISPER_MODEL)
                except ImportError:
                    logger.error("No whisper package available!")
                    raise
        return self._whisper_model

    async def transcribe_nvidia_riva(
        self, audio_bytes: bytes, language_code: str = "en-US"
    ) -> Tuple[str, str]:
        """
        Transcribe audio using NVIDIA Riva ASR REST API.
        Returns: (transcribed_text, detected_language)
        """
        # Map 2-letter lang codes to Riva format
        riva_lang_map = {
            "en": "en-US", "hi": "hi-IN", "te": "te-IN",
            "ta": "ta-IN", "kn": "kn-IN", "ml": "ml-IN",
            "bn": "bn-IN", "mr": "mr-IN", "gu": "gu-IN", "pa": "pa-IN"
        }
        riva_lang = riva_lang_map.get(language_code, "en-US")

        headers = {
            "Authorization": f"Bearer {settings.NVIDIA_API_KEY}",
            "Content-Type": "audio/wav",
        }
        params = {"language_code": riva_lang}

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{settings.RIVA_ASR_URL}/asr",
                    content=audio_bytes,
                    headers=headers,
                    params=params
                )
                if response.status_code == 200:
                    data = response.json()
                    text = data.get("transcript", "")
                    detected_lang = data.get("language", language_code)
                    return text, detected_lang
                else:
                    logger.warning(f"Riva ASR returned {response.status_code}, falling back")
                    raise Exception(f"Riva ASR error: {response.status_code}")
        except Exception as e:
            logger.warning(f"Riva ASR failed: {e}. Using Whisper fallback.")
            return await self.transcribe_whisper(audio_bytes)

    async def transcribe_whisper(
        self, audio_bytes: bytes, language_hint: Optional[str] = None
    ) -> Tuple[str, str]:
        """
        Transcribe using local Whisper model.
        Returns: (transcribed_text, detected_language)
        """
        import asyncio

        def _run_whisper():
            model = self._get_whisper_model()
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
                f.write(audio_bytes)
                tmp_path = f.name

            try:
                # Check if faster-whisper or openai-whisper
                if hasattr(model, 'transcribe') and hasattr(model, 'model'):
                    # faster-whisper
                    segments, info = model.transcribe(
                        tmp_path,
                        language=language_hint,
                        beam_size=5
                    )
                    text = " ".join([seg.text for seg in segments]).strip()
                    detected_lang = info.language
                else:
                    # openai-whisper
                    result = model.transcribe(tmp_path, language=language_hint)
                    text = result["text"].strip()
                    detected_lang = result.get("language", "en")
                return text, detected_lang
            finally:
                os.unlink(tmp_path)

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _run_whisper)

    async def transcribe(
        self, audio_bytes: bytes, language_hint: Optional[str] = None
    ) -> Tuple[str, str]:
        """
        Main transcription method - tries NVIDIA Riva first, then Whisper.
        Returns: (transcribed_text, detected_language_code)
        """
        if not audio_bytes:
            raise ValueError("No audio data provided")

        if settings.NVIDIA_API_KEY and settings.NVIDIA_API_KEY != "your-nvidia-api-key-here":
            try:
                return await self.transcribe_nvidia_riva(audio_bytes, language_hint or "en")
            except Exception as e:
                logger.warning(f"NVIDIA ASR failed, using fallback: {e}")

        # Fallback to Whisper
        return await self.transcribe_whisper(audio_bytes, language_hint)


# Singleton instance
asr_service = ASRService()
