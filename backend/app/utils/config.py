"""
Configuration management for the backend
Reads from environment variables with sensible defaults
"""

import os
from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # NVIDIA API Configuration
    NVIDIA_API_KEY: str = os.getenv("NVIDIA_API_KEY", "your-nvidia-api-key-here")
    NVIDIA_BASE_URL: str = "https://integrate.api.nvidia.com/v1"
    
    # OpenAI-compatible endpoint for NVIDIA NIM LLMs
    NVIDIA_NIM_URL: str = "https://integrate.api.nvidia.com/v1"
    NVIDIA_LLM_MODEL: str = "meta/llama-3.1-8b-instruct"
    
    # Riva ASR/TTS endpoints (self-hosted or cloud)
    RIVA_ASR_URL: str = os.getenv("RIVA_ASR_URL", "grpc://localhost:50051")
    RIVA_TTS_URL: str = os.getenv("RIVA_TTS_URL", "grpc://localhost:50051")
    
    # Fallback settings
    USE_FALLBACK: bool = True  # Use open-source fallbacks when NVIDIA APIs unavailable
    WHISPER_MODEL: str = "base"  # Options: tiny, base, small, medium
    
    # TTS Settings
    DEFAULT_TTS_SPEED: float = 0.85  # Slower than normal for clarity
    
    # Supported Languages
    SUPPORTED_LANGUAGES: list = ["te", "hi", "ta", "en", "kn", "ml", "bn", "mr", "gu", "pa"]
    
    # Voice mappings for TTS
    VOICE_MAP: dict = {
        "te": "Telugu_Female",
        "hi": "Hindi_Male", 
        "ta": "Tamil_Female",
        "en": "English_Female",
        "kn": "Kannada_Female",
        "ml": "Malayalam_Female",
        "bn": "Bengali_Female",
        "mr": "Marathi_Female",
        "gu": "Gujarati_Female",
        "pa": "Punjabi_Male",
    }
    
    # Edge TTS voices (fallback)
    EDGE_TTS_VOICE_MAP: dict = {
        "te": "te-IN-ShrutiNeural",
        "hi": "hi-IN-SwaraNeural",
        "ta": "ta-IN-PallaviNeural",
        "en": "en-IN-NeerjaNeural",
        "kn": "kn-IN-SapnaNeural",
        "ml": "ml-IN-SobhanaNeural",
        "bn": "bn-IN-TanishaaNeural",
        "mr": "mr-IN-AarohiNeural",
        "gu": "gu-IN-DhwaniNeural",
        "pa": "pa-IN-OjaswanthNeural",
    }
    
    # Language display names
    LANGUAGE_NAMES: dict = {
        "te": "Telugu",
        "hi": "Hindi",
        "ta": "Tamil",
        "en": "English",
        "kn": "Kannada",
        "ml": "Malayalam",
        "bn": "Bengali",
        "mr": "Marathi",
        "gu": "Gujarati",
        "pa": "Punjabi",
    }
    
    # File upload limits
    MAX_AUDIO_SIZE_MB: int = 25
    MAX_IMAGE_SIZE_MB: int = 10
    
    # Session settings
    SESSION_TIMEOUT_SECONDS: int = 300
    
    DEBUG: str = "False"
    ALLOWED_ORIGINS: str = "*"
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"


settings = Settings()
