# 🌐 Multilingual Communication Bridge
### Complete Setup Guide — Step by Step

---

## 📁 Project Structure

```
multilingual_bridge/
├── backend/                    ← Python FastAPI server (the brain)
│   ├── app/
│   │   ├── main.py             ← Entry point
│   │   ├── api/                ← Route handlers
│   │   │   ├── voice.py        ← Speech endpoints
│   │   │   ├── translate.py    ← Translation endpoints
│   │   │   ├── paste_reply.py  ← 📋 Star feature endpoints
│   │   │   ├── image.py        ← OCR endpoints
│   │   │   └── conversation.py ← Two-person mode
│   │   ├── services/           ← AI service wrappers
│   │   │   ├── asr_service.py  ← Speech recognition
│   │   │   ├── tts_service.py  ← Text to speech
│   │   │   ├── translation_service.py
│   │   │   ├── llm_service.py  ← LLM (slang, explanation)
│   │   │   └── ocr_service.py  ← Image text extraction
│   │   ├── models/schemas.py   ← API data models
│   │   └── utils/config.py     ← Configuration
│   ├── requirements.txt        ← All Python packages
│   ├── requirements-minimal.txt← Quick start packages
│   └── .env.example            ← Environment variables template
│
└── flutter_app/                ← Mobile app (Android/iOS)
    ├── lib/
    │   ├── main.dart            ← App entry point
    │   ├── screens/             ← UI screens
    │   │   ├── home_screen.dart
    │   │   ├── paste_reply_screen.dart  ← Star feature UI
    │   │   ├── voice_query_screen.dart
    │   │   ├── screenshot_screen.dart
    │   │   ├── conversation_screen.dart
    │   │   └── settings_screen.dart
    │   ├── services/
    │   │   ├── api_service.dart
    │   │   ├── audio_service.dart
    │   │   └── preferences_service.dart
    │   └── widgets/
    │       ├── record_button.dart
    │       ├── loading_overlay.dart
    │       └── language_selector.dart
    └── pubspec.yaml
```

---

## 🛠️ PHASE 1 — Install Prerequisites

### Step 1.1 — Install Python 3.11+

**Windows:**
```
Download from: https://www.python.org/downloads/
✅ During install: Check "Add Python to PATH"
```

**Mac:**
```bash
brew install python@3.11
```

**Linux/Ubuntu:**
```bash
sudo apt update
sudo apt install python3.11 python3.11-pip python3.11-venv -y
```

**Verify:**
```bash
python --version
# Should show: Python 3.11.x or higher
```

---

### Step 1.2 — Install Flutter SDK

1. Download Flutter SDK from: https://flutter.dev/docs/get-started/install
2. Extract to a folder like `C:\flutter` (Windows) or `~/flutter` (Mac/Linux)
3. Add to PATH:
   - **Windows:** Add `C:\flutter\bin` to System Environment Variables → PATH
   - **Mac/Linux:** Add to `~/.bashrc` or `~/.zshrc`:
     ```bash
     export PATH="$PATH:$HOME/flutter/bin"
     ```
4. Verify:
   ```bash
   flutter --version
   flutter doctor
   ```
   Fix any issues that `flutter doctor` reports.

---

### Step 1.3 — Install Android Studio (for Android development)

1. Download from: https://developer.android.com/studio
2. During install, include:
   - Android SDK
   - Android SDK Platform Tools
   - Android Emulator
3. Open Android Studio → SDK Manager → Install:
   - Android API 34 (or latest)
   - Android Emulator
4. Create a virtual device:
   - Tools → Device Manager → Create Device
   - Choose Pixel 6 Pro, API 34

---

### Step 1.4 — Install VS Code Extensions

Open VS Code and install these extensions:
- **Python** (by Microsoft)
- **Flutter** (by Dart Code)
- **Dart** (by Dart Code)
- **REST Client** (by Huachao Mao) — for testing APIs

---

## 🔑 PHASE 2 — Get NVIDIA API Key (Free)

### Step 2.1 — Create NVIDIA Account

1. Go to: **https://build.nvidia.com/**
2. Click **"Sign In"** → Create a free account
3. After login, go to any model (e.g., Llama 3.1): https://build.nvidia.com/meta/llama-3_1-8b-instruct
4. Click **"Get API Key"** → Copy the key (starts with `nvapi-`)
5. You get **1000 free credits** — enough for extensive testing

---

## ⚙️ PHASE 3 — Backend Setup

### Step 3.1 — Open the Backend Folder in VS Code Terminal

```bash
# Open VS Code
# File → Open Folder → Select: multilingual_bridge/backend

# Open Terminal in VS Code: Ctrl+` (backtick)
```

### Step 3.2 — Create Python Virtual Environment

```bash
# Create venv
python -m venv venv

# Activate (Windows):
venv\Scripts\activate

# Activate (Mac/Linux):
source venv/bin/activate

# You should see (venv) at the start of your terminal prompt
```

### Step 3.3 — Install Python Packages (Quick Start)

For a fast start, install the minimal requirements first:

```bash
pip install -r requirements-minimal.txt
```

This installs: FastAPI, edge-tts (free TTS), langdetect, and core packages.

**For full features (including local ASR & translation):**
```bash
pip install -r requirements.txt
```

⚠️ Note: `torch` and `transformers` are large (~2GB). Skip if using NVIDIA APIs.

### Step 3.4 — Create Your .env File

```bash
# Copy the example file
cp .env.example .env

# Open .env in VS Code and edit it
```

**Edit `.env`:**
```
NVIDIA_API_KEY=nvapi-YOUR_KEY_HERE   ← paste your key
NVIDIA_LLM_MODEL=meta/llama-3.1-8b-instruct
USE_FALLBACK=False
WHISPER_MODEL=base
DEFAULT_TTS_SPEED=0.85
```

### Step 3.5 — Start the Backend Server

```bash
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Expected output:**
```
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Started reloader process
INFO:     Application startup complete.
```

### Step 3.6 — Test the Backend

Open your browser: **http://localhost:8000/docs**

You should see the interactive API documentation (Swagger UI).

**Test via terminal (new terminal window):**
```bash
# Health check
curl http://localhost:8000/health

# Test translation (simple text)
curl -X POST http://localhost:8000/api/translate/translate \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, how are you?", "target_lang": "hi"}'

# Test language detection
curl -X POST http://localhost:8000/api/translate/detect-language \
  -H "Content-Type: application/json" \
  -d '{"text": "नमस्ते, आप कैसे हैं?"}'
```

---

## 📱 PHASE 4 — Flutter App Setup

### Step 4.1 — Open Flutter App in VS Code

```bash
# Open a new VS Code window
# File → Open Folder → Select: multilingual_bridge/flutter_app
```

### Step 4.2 — Get Flutter Dependencies

```bash
# In VS Code terminal (Ctrl+`)
flutter pub get
```

### Step 4.3 — Create Required Asset Folders

```bash
mkdir -p assets/audio assets/images assets/fonts
```

### Step 4.4 — Check Flutter Setup

```bash
flutter doctor
# All items should have green checkmarks
# If Android SDK is missing, run: flutter doctor --android-licenses
```

### Step 4.5 — Start Android Emulator

```bash
# List available emulators
flutter emulators

# Start an emulator (replace with your emulator name)
flutter emulators --launch Pixel_6_Pro_API_34

# OR open Android Studio → Device Manager → Play button
```

### Step 4.6 — Run the Flutter App

```bash
# Check connected devices
flutter devices

# Run the app (it will auto-select the emulator)
flutter run

# For specific device:
flutter run -d emulator-5554
```

---

## 🔗 PHASE 5 — Connect App to Backend

### Step 5.1 — Find Your Computer's IP Address

**Windows:**
```bash
ipconfig
# Look for: IPv4 Address . . . . . . . . : 192.168.x.x
```

**Mac/Linux:**
```bash
ifconfig | grep inet
# Or:
hostname -I
```

### Step 5.2 — Configure Server URL in App

**Option A — Android Emulator (same computer):**
```
Use: http://10.0.2.2:8000
(10.0.2.2 is the special IP that points to your computer from the emulator)
```

**Option B — Physical Android Phone:**
```
1. Connect phone via USB
2. Enable Developer Mode on phone:
   Settings → About Phone → Tap "Build Number" 7 times
3. Enable USB Debugging:
   Settings → Developer Options → USB Debugging → ON
4. Use your computer's LAN IP, e.g.: http://192.168.1.5:8000
```

**Set in App:**
- Open the app → Settings ⚙️ → Server URL → Enter your URL → Save

---

## 🧪 PHASE 6 — Test All Features

### Test 1: Paste & Reply (Star Feature)
1. Open WhatsApp / Telegram
2. Long-press any message → Copy
3. Open Multilingual Bridge app
4. Tap 📋 **Paste & Reply**
5. Tap the orange **PASTE** button
6. Watch the app detect language, explain the message, and speak it
7. Tap **Reply** → Hold microphone → Speak your reply in your language
8. Tap **COPY** → Go back to WhatsApp → Paste

### Test 2: Voice Query
1. Tap 🎤 **Speak & Translate**
2. Hold the microphone button
3. Speak: "Hello, what is your name?" in English
4. Release → Hear the Hindi translation

### Test 3: Screenshot
1. Take a screenshot of any text (menu, sign, document)
2. Tap 📷 **Screenshot**
3. Tap **From Gallery** → Select the screenshot
4. The app reads and translates the text

### Test 4: Two-Person Conversation
1. Tap 👥 **Two-Person Talk**
2. Set Person 1 = Hindi, Person 2 = English
3. Tap Person 1's button → Speak in Hindi → Release
4. Hear English translation for Person 2
5. Tap Person 2's button → Speak in English → Release
6. Hear Hindi translation for Person 1

---

## 🚀 PHASE 7 — Add More AI Capabilities (Optional)

### Add Local Speech Recognition (Whisper)

```bash
# In backend venv terminal:
pip install faster-whisper

# In .env:
WHISPER_MODEL=base
USE_FALLBACK=True
```

### Add Local Translation (M2M-100)

```bash
pip install transformers torch sentencepiece
# Warning: Downloads ~1.5GB model on first use
```

### Add OCR for Screenshots

```bash
pip install paddlepaddle paddleocr Pillow

# Linux only - install system deps:
sudo apt install libgomp1 -y
```

### Add Local Language Detection

```bash
pip install lingua-language-detector
# OR faster but less accurate:
pip install langdetect
```

---

## 🏗️ PHASE 8 — Build Production APK

### Build Release APK for Android

```bash
# In flutter_app directory:
flutter build apk --release

# APK will be at:
# build/app/outputs/flutter-apk/app-release.apk

# Install on connected phone:
flutter install
```

---

## 🐛 Troubleshooting

### Backend Issues

| Problem | Solution |
|---------|----------|
| `ModuleNotFoundError: No module named 'fastapi'` | Run `pip install -r requirements-minimal.txt` inside venv |
| `venv\Scripts\activate` not working (Windows) | Run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Port 8000 already in use | Change port: `uvicorn app.main:app --port 8001` |
| NVIDIA API key error | Check `.env` file, ensure key starts with `nvapi-` |
| Edge TTS not working | Run: `pip install edge-tts` |

### Flutter Issues

| Problem | Solution |
|---------|----------|
| `flutter: command not found` | Add Flutter to PATH (see Step 1.2) |
| `No devices found` | Start emulator or connect phone with USB debugging ON |
| `Microphone permission denied` | On emulator: Extended Controls → Microphone → Allow |
| App can't reach backend | Check Server URL in Settings. Use `10.0.2.2:8000` for emulator |
| `flutter pub get` fails | Run: `flutter clean && flutter pub get` |

### API Issues

| Problem | Solution |
|---------|----------|
| Translation returns error | Check NVIDIA API key in `.env` |
| TTS audio not playing | Test with: `curl -X POST .../api/paste-reply/tts -d "text=Hello&language_code=en&speed=slow"` |
| OCR not working | Install PaddleOCR: `pip install paddleocr paddlepaddle` |

---

## 💡 Quick Commands Reference

```bash
# ── BACKEND ──────────────────────────────────────────────
# Start server
cd multilingual_bridge/backend
source venv/bin/activate          # Mac/Linux
# OR: venv\Scripts\activate       # Windows
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Test health
curl http://localhost:8000/health

# View API docs
# Open browser: http://localhost:8000/docs

# ── FLUTTER APP ───────────────────────────────────────────
# Start app
cd multilingual_bridge/flutter_app
flutter pub get
flutter run

# Build APK
flutter build apk --release

# Hot reload (while app is running)
# Press 'r' in terminal
# Press 'R' for full restart

# ── BOTH AT ONCE (two terminals) ─────────────────────────
# Terminal 1: Start backend
# Terminal 2: flutter run
```

---

## 📊 Architecture Flow

```
User speaks / pastes text
        ↓
Flutter App (Mobile)
        ↓  HTTP/HTTPS
FastAPI Backend
        ↓
   ┌────┴────────────────────┐
   │                         │
NVIDIA APIs              Fallback (Free)
• NIM LLM (Llama 3.1)   • Whisper (ASR)
• Riva ASR               • M2M-100 (Translation)
• Riva TTS               • Edge-TTS (TTS)
• NeMo MT                • PaddleOCR (OCR)
   │                         │
   └────────────┬────────────┘
                ↓
         Response Audio + Text
                ↓
          Flutter App
     (plays audio + shows text)
```

---

## 🔒 Security Notes

- Never commit your `.env` file (it's in `.gitignore`)
- For production, use HTTPS (get a domain + SSL certificate)
- The Android manifest has `usesCleartextTraffic="true"` for local dev — remove for production HTTPS

---

## 📞 Support

- NVIDIA API Docs: https://docs.api.nvidia.com/
- FastAPI Docs: https://fastapi.tiangolo.com/
- Flutter Docs: https://flutter.dev/docs
- Edge-TTS (free TTS): https://github.com/rany2/edge-tts
