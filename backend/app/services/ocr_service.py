"""
OCR Service for Screenshot Processing
Primary: PaddleOCR (multi-language, fast)
Fallback: pytesseract
"""

import logging
import io
from typing import Optional
import base64
import httpx

from app.utils.config import settings

logger = logging.getLogger(__name__)


class OCRService:
    """
    OCR service for extracting text from screenshots and images.
    """

    def __init__(self):
        self._paddle_ocr = None

    def _get_paddle_ocr(self):
        """Lazy load PaddleOCR."""
        if self._paddle_ocr is None:
            try:
                from paddleocr import PaddleOCR
                logger.info("Loading PaddleOCR...")
                self._paddle_ocr = PaddleOCR(
                    use_angle_cls=True,
                    lang='en',
                    show_log=False
                )
                logger.info("PaddleOCR loaded")
            except ImportError:
                logger.warning("PaddleOCR not installed")
                raise
        return self._paddle_ocr

    async def extract_text_paddle(self, image_bytes: bytes) -> str:
        """Extract text from image using PaddleOCR."""
        import asyncio
        import numpy as np
        from PIL import Image

        def _run():
            ocr = self._get_paddle_ocr()
            # Convert bytes to numpy array
            img = Image.open(io.BytesIO(image_bytes))
            img_array = np.array(img)

            result = ocr.ocr(img_array, cls=True)

            # Extract all text lines
            lines = []
            if result and result[0]:
                for line in result[0]:
                    if line and len(line) > 1:
                        text = line[1][0]
                        confidence = line[1][1]
                        if confidence > 0.5:  # Only high-confidence text
                            lines.append(text)

            return "\n".join(lines)

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _run)

    async def extract_text_tesseract(self, image_bytes: bytes) -> str:
        """Extract text using pytesseract (fallback)."""
        import asyncio

        def _run():
            try:
                import pytesseract
                from PIL import Image
                img = Image.open(io.BytesIO(image_bytes))
                # Try multiple languages
                text = pytesseract.image_to_string(
                    img,
                    lang='eng+hin+tel+tam+kan+mal',  # Multiple language support
                    config='--psm 6'
                )
                return text.strip()
            except Exception as e:
                logger.error(f"Tesseract failed: {e}")
                return ""

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _run)

    async def extract_text_nvidia_vlm(
        self, image_bytes: bytes, question: str = "What text is in this image?"
    ) -> str:
        """
        Use NVIDIA Vision-Language Model (LLaVA/NVLM) for image understanding.
        Can answer questions about image content beyond just text.
        """
        # Convert image to base64
        img_b64 = base64.b64encode(image_bytes).decode("utf-8")

        headers = {
            "Authorization": f"Bearer {settings.NVIDIA_API_KEY}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": "nvidia/llava-v1.6-mistral-7b",  # or other VLM
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{img_b64}"
                            }
                        },
                        {
                            "type": "text",
                            "text": question
                        }
                    ]
                }
            ],
            "max_tokens": 500,
        }

        try:
            async with httpx.AsyncClient(timeout=45.0) as client:
                response = await client.post(
                    f"{settings.NVIDIA_NIM_URL}/chat/completions",
                    json=payload,
                    headers=headers
                )
                if response.status_code == 200:
                    data = response.json()
                    return data["choices"][0]["message"]["content"].strip()
                raise Exception(f"VLM error: {response.status_code}")
        except Exception as e:
            logger.warning(f"NVIDIA VLM failed: {e}")
            raise

    async def process_screenshot(
        self,
        image_bytes: bytes,
        question: Optional[str] = None
    ) -> dict:
        """
        Main method: Extract text from screenshot and optionally answer a question.
        Returns: {extracted_text, answer (if question provided)}
        """
        extracted_text = ""

        # Try PaddleOCR first
        try:
            extracted_text = await self.extract_text_paddle(image_bytes)
        except Exception as e:
            logger.warning(f"PaddleOCR failed: {e}, trying tesseract")
            try:
                extracted_text = await self.extract_text_tesseract(image_bytes)
            except Exception as e2:
                logger.warning(f"Tesseract also failed: {e2}")

        result = {"extracted_text": extracted_text, "answer": None}

        # If a question is asked, use VLM
        if question and settings.NVIDIA_API_KEY != "your-nvidia-api-key-here":
            try:
                full_question = f"{question}\n\nText in image: {extracted_text}"
                answer = await self.extract_text_nvidia_vlm(image_bytes, full_question)
                result["answer"] = answer
            except Exception as e:
                logger.warning(f"VLM question answering failed: {e}")
                # Use extracted text as answer
                result["answer"] = extracted_text

        return result


# Singleton
ocr_service = OCRService()
