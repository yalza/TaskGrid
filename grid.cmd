@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\grid.ps1" %*
