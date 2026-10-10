@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\task-grid.ps1" %*
