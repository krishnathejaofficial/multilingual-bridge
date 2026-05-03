#!/bin/bash
echo "========================================"
echo "  Multilingual Bridge - Backend Startup "
echo "========================================"
echo ""

cd "$(dirname "$0")/backend"

if [ ! -d "venv" ]; then
    echo "[1/3] Creating Python virtual environment..."
    python3 -m venv venv
fi

echo "[2/3] Activating virtual environment..."
source venv/bin/activate

echo "[3/3] Installing packages..."
pip install -r requirements-minimal.txt --quiet

if [ ! -f ".env" ]; then
    echo ""
    echo "[!] .env file not found. Copying from .env.example..."
    cp .env.example .env
    echo "[!] Please open backend/.env and add your NVIDIA_API_KEY"
    echo "[!] Get your free key at: https://build.nvidia.com/"
    echo ""
    read -p "Press Enter to continue after editing .env..."
fi

echo ""
echo "Starting FastAPI server on http://localhost:8000"
echo "API Docs: http://localhost:8000/docs"
echo "Press CTRL+C to stop"
echo ""
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
