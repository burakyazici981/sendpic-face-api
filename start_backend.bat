@echo off
echo Starting SendPic Backend Server...
echo.

cd /d "%~dp0face_recognition_server"

echo Checking Python installation...
python --version
if %errorlevel% neq 0 (
    echo ERROR: Python not found! Please install Python 3.11+
    pause
    exit /b 1
)

echo.
echo Installing dependencies...
python -m pip install -r requirements.txt

echo.
echo Starting server on port 5050...
echo Backend will be available at: http://localhost:5050
echo Press Ctrl+C to stop the server
echo.

python main.py

pause
