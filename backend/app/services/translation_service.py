"""
Machine Translation (MT) Service
Primary: NVIDIA NIM (NeMo MT / SeamlessM4T via OpenAI-compatible API)
Fallback: Facebook M2M-100 or NLLB-200
Also handles: Language Identification (LID)
"""

import logging
from typing import Optional, Tuple
import httpx

from app.utils.config import settings

logger = logging.getLogger(__name__)


class TranslationService:
    """
    Translation and language identification service.
    """

    def __init__(self):
        self._m2m_model = None
        self._m2m_tokenizer = None
        self._lid_model = None

    # ── Language Detection ──────────────────────────────────────────────────

    async def detect_language(self, text: str) -> str:
        """
        Detect language of input text.
        Returns ISO 639-1 language code (e.g., 'hi', 'te', 'en')
        """
        # Try lingua-py first (very fast, no GPU needed)
        try:
            from lingua import Language, LanguageDetectorBuilder
            detector = LanguageDetectorBuilder.from_all_languages().build()
            lang = detector.detect_language_of(text)
            if lang:
                return lang.iso_code_639_1.name.lower()
        except ImportError:
            pass

        # Try langdetect fallback
        try:
            from langdetect import detect
            lang_code = detect(text)
            return lang_code
        except ImportError:
            pass

        # Try fasttext if available
        try:
            import fasttext
            # Requires fasttext model to be downloaded
            prediction = self._lid_model.predict(text.replace("\n", " "))
            lang = prediction[0][0].replace("__label__", "")
            return lang
        except Exception:
            pass

        logger.warning("All LID methods failed, defaulting to 'en'")
        return "en"

    # ── NVIDIA NIM Translation ──────────────────────────────────────────────

    async def translate_nvidia_nim(
        self, text: str, source_lang: str, target_lang: str
    ) -> str:
        """
        Translate using NVIDIA NIM endpoint (OpenAI-compatible).
        """
        src_name = settings.LANGUAGE_NAMES.get(source_lang, source_lang)
        tgt_name = settings.LANGUAGE_NAMES.get(target_lang, target_lang)

        prompt = (
            f"Translate the following text from {src_name} to {tgt_name}. "
            f"Output ONLY the translated text, nothing else.\n\n"
            f"Text: {text}\n\nTranslation:"
        )

        headers = {
            "Authorization": f"Bearer {settings.NVIDIA_API_KEY}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": settings.NVIDIA_LLM_MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 500,
            "temperature": 0.1,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{settings.NVIDIA_NIM_URL}/chat/completions",
                    json=payload,
                    headers=headers
                )
                if response.status_code == 200:
                    data = response.json()
                    return data["choices"][0]["message"]["content"].strip()
                else:
                    raise Exception(f"NIM MT error: {response.status_code} - {response.text}")
        except Exception as e:
            logger.warning(f"NVIDIA NIM translation failed: {e}")
            raise

    # ── M2M-100 Fallback Translation ────────────────────────────────────────

    def _get_m2m_model(self):
        """Lazy load M2M-100 model."""
        if self._m2m_model is None:
            try:
                from transformers import M2M100ForConditionalGeneration, M2M100Tokenizer
                import torch
                model_name = "facebook/m2m100_418M"  # Smaller, faster
                logger.info(f"Loading M2M-100 model: {model_name}")
                self._m2m_tokenizer = M2M100Tokenizer.from_pretrained(model_name)
                self._m2m_model = M2M100ForConditionalGeneration.from_pretrained(model_name)
                logger.info("M2M-100 model loaded")
            except Exception as e:
                logger.error(f"Failed to load M2M-100: {e}")
                raise
        return self._m2m_model, self._m2m_tokenizer

    async def translate_m2m100(
        self, text: str, source_lang: str, target_lang: str
    ) -> str:
        """Translate using local M2M-100 model."""
        import asyncio

        def _run():
            model, tokenizer = self._get_m2m_model()
            tokenizer.src_lang = source_lang
            encoded = tokenizer(text, return_tensors="pt")
            lang_map = {
                "te": "te", "hi": "hi", "ta": "ta", "en": "en",
                "kn": "kn", "ml": "ml", "bn": "bn", "mr": "mr",
                "gu": "gu", "pa": "pa"
            }
            tgt = lang_map.get(target_lang, target_lang)
            generated_tokens = model.generate(
                **encoded,
                forced_bos_token_id=tokenizer.get_lang_id(tgt)
            )
            return tokenizer.batch_decode(generated_tokens, skip_special_tokens=True)[0]

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _run)

    # ── Main Translate Method ───────────────────────────────────────────────

    async def translate(
        self, text: str, source_lang: str, target_lang: str
    ) -> str:
        """
        Translate text from source to target language.
        Tries NVIDIA NIM first, then M2M-100 fallback.
        """
        if source_lang == target_lang:
            return text  # No translation needed

        if not text.strip():
            return text

        if settings.NVIDIA_API_KEY and settings.NVIDIA_API_KEY != "your-nvidia-api-key-here":
            try:
                return await self.translate_nvidia_nim(text, source_lang, target_lang)
            except Exception as e:
                logger.warning(f"NVIDIA translation failed, using M2M-100: {e}")

        try:
            return await self.translate_m2m100(text, source_lang, target_lang)
        except Exception as e:
            logger.error(f"All translation methods failed: {e}")
            return f"[Translation failed: {text}]"


# Singleton
translation_service = TranslationService()
