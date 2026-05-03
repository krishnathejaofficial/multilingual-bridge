"""
LLM Service for:
1. Normalizing informal chat text (slang, abbreviations, emojis)
2. Generating explanations in simple language
3. Emoji sentiment analysis
"""

import logging
from typing import Optional
import httpx

from app.utils.config import settings

logger = logging.getLogger(__name__)

# ── Prompts ──────────────────────────────────────────────────────────────────

NORMALIZE_PROMPT = """You are a chat assistant that helps expand informal messages.
The user has pasted a chat message that may contain:
- Shortcuts (r u, tmrw, gr8, brb, lol, btw, idk, omg, etc.)
- Abbreviations
- Informal spellings
- Emojis (describe them in parentheses)
- Slang words

Your task: Rewrite the message using complete words and standard grammar.
Preserve the meaning and emotional tone exactly.
Output ONLY the expanded message, nothing else.

Examples:
Input: "r u cumin 2day? gr8!"
Output: "Are you coming today? Great!"

Input: "can't talk now, brb 😉"
Output: "I cannot talk now, I will be right back (winking face)."

Input: "omg that's so cute 😍 luv it"
Output: "Oh my God, that is so cute (smiling face with heart eyes). I love it."

Input: "tmrw meeting at 10, dnt b l8"
Output: "Tomorrow meeting at 10, do not be late."

Now expand this message:
Input: "{message}"
Output:"""

EXPLAIN_PROMPT = """You are a helpful assistant explaining a chat message to someone who received it.
The person receiving this message speaks {user_language} and wants to understand what was sent.

Message to explain: "{message}"

Write a clear, simple explanation in {user_language} that covers:
1. What the main message says
2. The tone (friendly, urgent, angry, casual, etc.)
3. What action (if any) is expected

Keep the explanation short (2-3 sentences). Use very simple words.
Output ONLY the explanation in {user_language}, nothing else."""

SENTIMENT_PROMPT = """Analyze the emotional tone of this chat message and respond in {user_language}.
Message: "{message}"

In one short sentence, describe the emotional tone (e.g., friendly, urgent, angry, worried, happy, sad).
Output ONLY the tone description in {user_language}."""

REPLY_HELP_PROMPT = """The user wants to reply to this message: "{original_message}"
The user's spoken reply (in their native language) is: "{user_reply}"

Help craft a natural, contextually appropriate reply.
The reply should match the tone of the conversation.
Output ONLY the reply text, nothing else."""


class LLMService:
    """
    LLM service for text normalization, explanation, and reply generation.
    """

    async def _call_nvidia_nim(self, prompt: str, max_tokens: int = 300) -> str:
        """Call NVIDIA NIM LLM API (OpenAI-compatible)."""
        headers = {
            "Authorization": f"Bearer {settings.NVIDIA_API_KEY}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": settings.NVIDIA_LLM_MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
            "temperature": 0.2,
        }

        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(
                f"{settings.NVIDIA_NIM_URL}/chat/completions",
                json=payload,
                headers=headers
            )
            if response.status_code == 200:
                data = response.json()
                return data["choices"][0]["message"]["content"].strip()
            else:
                raise Exception(f"NIM LLM error: {response.status_code} - {response.text}")

    async def _call_ollama(self, prompt: str, model: str = "llama3") -> str:
        """Call local Ollama instance as fallback."""
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {"temperature": 0.2, "num_predict": 300}
        }
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                "http://localhost:11434/api/generate",
                json=payload
            )
            if response.status_code == 200:
                return response.json()["response"].strip()
            raise Exception(f"Ollama error: {response.status_code}")

    async def _call_llm(self, prompt: str, max_tokens: int = 300) -> str:
        """
        Try NVIDIA NIM first, then Ollama, then simple rule-based fallback.
        """
        if settings.NVIDIA_API_KEY and settings.NVIDIA_API_KEY != "your-nvidia-api-key-here":
            try:
                return await self._call_nvidia_nim(prompt, max_tokens)
            except Exception as e:
                logger.warning(f"NVIDIA NIM failed: {e}")

        try:
            return await self._call_ollama(prompt)
        except Exception as e:
            logger.warning(f"Ollama failed: {e}")

        # Basic fallback for normalization
        logger.warning("All LLM methods failed, returning original text")
        return prompt.split('Input: "')[-1].split('"')[0] if 'Input: "' in prompt else ""

    async def normalize_chat_message(self, message: str) -> str:
        """
        Expand abbreviations, slang, and emojis in a chat message.
        Returns normalized (expanded) text.
        """
        if not message.strip():
            return message

        prompt = NORMALIZE_PROMPT.format(message=message)
        normalized = await self._call_llm(prompt, max_tokens=200)

        # Fallback: return original if LLM returns empty
        return normalized if normalized else message

    async def explain_message(
        self, message: str, user_language_name: str = "English"
    ) -> str:
        """
        Generate a simple explanation of a message in the user's language.
        """
        prompt = EXPLAIN_PROMPT.format(
            message=message,
            user_language=user_language_name
        )
        return await self._call_llm(prompt, max_tokens=200)

    async def get_sentiment(
        self, message: str, user_language_name: str = "English"
    ) -> str:
        """
        Analyze and return the emotional tone of a message.
        """
        prompt = SENTIMENT_PROMPT.format(
            message=message,
            user_language=user_language_name
        )
        return await self._call_llm(prompt, max_tokens=100)

    async def generate_contextual_reply(
        self, original_message: str, user_reply: str
    ) -> str:
        """
        Help craft a better reply based on context.
        """
        prompt = REPLY_HELP_PROMPT.format(
            original_message=original_message,
            user_reply=user_reply
        )
        return await self._call_llm(prompt, max_tokens=200)


# Singleton
llm_service = LLMService()
