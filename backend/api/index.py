"""
Vercel Entry Point for Multilingual Bridge FastAPI app.
Vercel's Python runtime requires the ASGI app to be exposed from api/index.py
"""

from app.main import app  # noqa: F401 — Vercel picks up `app` automatically
