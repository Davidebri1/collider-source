@echo off
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\serve.ps1"
