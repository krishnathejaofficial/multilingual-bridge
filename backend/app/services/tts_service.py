"""
Text-to-Speech (TTS) Service
Primary: NVIDIA Riva TTS
Fallback: Edge-TTS (Microsoft, free, excellent Indian language support)
"""

import asyncio
import logging
import io
import tempfile
import os
from typing import Optional

import httpx

from app.utils.config import settings

logger = logging.getLogger(__name__)


class TTSService:
    """
    Text-to-Speech service with multi-language, multi-voice support.
    Designed for slow, clear speech for illiterate users.
    """

    async def synthesize_edge_tts(
        self,
        text: str,
        language_code: str = "en",
        speed_rate: float = None
    ) -> bytes:
        """
        Generate speech using Microsoft Edge TTS (free, high-quality).
        Returns: audio bytes in MP3 format.
        """
        try:
            import edge_tts

            voice = settings.EDGE_TTS_VOICE_MAP.get(language_code, "en-IN-NeerjaNeural")
            rate = speed_rate or settings.DEFAULT_TTS_SPEED

            # Convert rate to Edge TTS format (+x% or -x%)
            # 0.85 speed = -15% rate
            rate_percent = int((rate - 1.0) * 100)
            rate_str = f"{rate_percent:+d}%"

            communicate = edge_tts.Communicate(text, voice, rate=rate_str)

            audio_chunks = []
            async for chunk in communicate.stream():
                if chunk["type"] == "audio":
                    audio_chunks.append(chunk["data"])

            return b"".join(audio_chunks)

        except ImportError:
            logger.error("edge-tts not installed. Run: pip install edge-tts")
            raise
        except Exception as e:
            logger.error(f"Edge TTS failed: {e}")
            raise

    async def synthesize_nvidia_riva(
        self,
        text: str,
        language_code: str = "en",
        speed_rate: float = None
    ) -> bytes:
        """
        Generate speech using NVIDIA Riva TTS.
        Returns: audio bytes in WAV format.
        """
        voice_id = settings.VOICE_MAP.get(language_code, "English_Female")
        rate = speed_rate or settings.DEFAULT_TTS_SPEED

        headers = {
            "Authorization": f"Bearer {settings.NVIDIA_API_KEY}",
            "Content-Type": "application/json",
        }
        payload = {
            "text": text,
            "voice_name": voice_id,
            "language_code": language_code,
            "speaking_rate": rate,
            "encoding": "LINEAR_PCM"
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{settings.RIVA_TTS_URL}/tts",
                    json=payload,
                    headers=headers
                )
                if response.status_code == 200:
                    return response.content
                else:
                    raise Exception(f"Riva TTS error: {response.status_code}")
        except Exception as e:
            logger.warning(f"Riva TTS failed: {e}")
            raise

    async def synthesize(
        self,
        text: str,
        language_code: str = "en",
        speed: str = "normal",  # "normal", "slow", "very_slow"
        return_format: str = "mp3"
    ) -> bytes:
        """
        Main TTS method. Returns audio bytes.
        speed options: "normal" (1.0), "slow" (0.85), "very_slow" (0.7)
        """
        speed_map = {"normal": 1.0, "slow": 0.85, "very_slow": 0.7}
        rate = speed_map.get(speed, 0.85)

        if not text.strip():
            raise ValueError("Empty text provided for TTS")

        # Try NVIDIA Riva first
        if settings.NVIDIA_API_KEY and settings.NVIDIA_API_KEY != "your-nvidia-api-key-here":
            try:
                return await self.synthesize_nvidia_riva(text, language_code, rate)
            except Exception as e:
                logger.warning(f"Riva TTS failed, using Edge TTS: {e}")

        # Fallback to Edge TTS
        return await self.synthesize_edge_tts(text, language_code, rate)

    async def synthesize_with_pauses(
        self,
        sentences: list[str],
        language_code: str = "en",
        speed: str = "slow"
    ) -> bytes:
        """
        Synthesize multiple sentences with clear pauses between them.
        Ideal for step-by-step instructions for illiterate users.
        """
        # Add SSML-style pauses by joining with punctuation
        combined = ". ".join([s.strip().rstrip(".") for s in sentences if s.strip()])
        return await self.synthesize(combined, language_code, speed)


# Singleton
tts_service = TTSService()
