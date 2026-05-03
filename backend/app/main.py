"""
Multilingual Communication Bridge - FastAPI Backend
Supports: ASR, Translation, TTS, LLM Normalization, OCR
Deployment: Vercel / Render / Railway
"""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
import logging

from app.api import voice, translate, paste_reply, image, conversation
from app.utils.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── CORS Origins ──────────────────────────────────────────────────────────────
# In production, restrict this to your actual frontend domain
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*").split(",")

app = FastAPI(
    title="Multilingual Communication Bridge API",
    description=(
        "Empathetic voice-first bridge for multilingual communication. "
        "Supports 10 Indian languages with ASR, Translation, TTS, OCR, and LLM features."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Include Routers ───────────────────────────────────────────────────────────
app.include_router(voice.router, prefix="/api/voice", tags=["Voice"])
app.include_router(translate.router, prefix="/api/translate", tags=["Translation"])
app.include_router(paste_reply.router, prefix="/api/paste-reply", tags=["Paste & Reply"])
app.include_router(image.router, prefix="/api/image", tags=["Image/OCR"])
app.include_router(conversation.router, prefix="/api/conversation", tags=["Conversation"])


@app.get("/", summary="API Root")
async def root():
    return {
        "message": "🌐 Multilingual Communication Bridge API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
        "supported_languages": list(settings.LANGUAGE_NAMES.values()),
        "features": ["ASR", "Translation", "TTS", "OCR", "LLM Normalization"]
    }


@app.get("/health", summary="Health Check")
async def health_check():
    """Returns service health status."""
    nvidia_configured = (
        bool(settings.NVIDIA_API_KEY) and
        settings.NVIDIA_API_KEY != "your-nvidia-api-key-here"
    )
    return {
        "status": "healthy",
        "nvidia_api": "configured" if nvidia_configured else "not configured (using fallbacks)",
        "services": {
            "asr": "nvidia-riva" if nvidia_configured else "whisper-fallback",
            "tts": "nvidia-riva" if nvidia_configured else "edge-tts-fallback",
            "translation": "nvidia-nim" if nvidia_configured else "m2m100-fallback",
            "llm": "nvidia-nim" if nvidia_configured else "ollama-fallback",
            "ocr": "nvidia-vlm" if nvidia_configured else "paddleocr-fallback",
        }
    }


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8000)),
        reload=os.getenv("DEBUG", "False").lower() == "true",
        log_level="info"
    )
