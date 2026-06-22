@echo off
python "%~dp0server.py" "%~dp0" %*
if %errorlevel% neq 0 (
    echo.
    echo Error: Make sure Python is installed and added to PATH.
    pause
)
