@echo off
echo ========================================
echo  Multilingual Bridge - Backend Startup
echo ========================================
echo.

cd backend

IF NOT EXIST venv (
    echo [1/3] Creating Python virtual environment...
    python -m venv venv
)

echo [2/3] Activating virtual environment...
call venv\Scripts\activate

echo [3/3] Installing packages...
pip install -r requirements-minimal.txt --quiet

IF NOT EXIST .env (
    echo.
    echo [!] .env file not found. Copying from .env.example...
    copy .env.example .env
    echo [!] Please open backend\.env and add your NVIDIA_API_KEY
    echo [!] Get your free key at: https://build.nvidia.com/
    echo.
    pause
)

echo.
echo Starting FastAPI server on http://localhost:8000
echo API Docs: http://localhost:8000/docs
echo Press CTRL+C to stop
echo.
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
