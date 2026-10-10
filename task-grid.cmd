@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0task-grid.ps1" %*
