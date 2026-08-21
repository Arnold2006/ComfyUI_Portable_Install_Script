@echo off
setlocal enabledelayedexpansion
title ComfyUI Portable Installer

:: =====================================================================
::  ComfyUI Portable Installer
::  - Downloads ComfyUI portable (CUDA 12 or CUDA 13 build)
::  - Extracts to chosen drive, renames root folder to "ComfyUI"
::  - Installs Git, clones a custom node pack, installs its requirements
::  - Installs ComfyUI-Manager requirements
::  - Patches run_nvidia_gpu.bat to enable the manager
::  - Optionally downloads the Ideogram 4 model files
:: =====================================================================

:: ---------------------------------------------------------------------
:: 1. Ask which drive to install to
:: ---------------------------------------------------------------------
:ask_drive
set "DRIVE="
set /p DRIVE="Enter the drive letter to install ComfyUI to (e.g. D): "
if "%DRIVE%"=="" goto ask_drive
set "DRIVE=%DRIVE::=%"
if not exist "%DRIVE%:\" (
    echo.
    echo Drive %DRIVE%: does not exist. Please try again.
    echo.
    goto ask_drive
)

set "INSTALL_ROOT=%DRIVE%:\"
set "COMFY_ROOT=%DRIVE%:\ComfyUI"

if exist "%COMFY_ROOT%" (
    echo.
    echo WARNING: "%COMFY_ROOT%" already exists.
    set /p OVERWRITE="Continue and extract into it anyway? (Y/N): "
    if /i not "!OVERWRITE!"=="Y" (
        echo Aborted by user.
        pause
        exit /b 1
    )
)

:: ---------------------------------------------------------------------
:: 2. Ask which CUDA version to download
:: ---------------------------------------------------------------------
:ask_cuda
echo.
echo Select which build to download:
echo.
echo   1. CUDA 13  - Required if you have an RTX 50-series (Blackwell) GPU.
echo                 Also works fine on RTX 20/30/40-series and older cards,
echo                 as long as your NVIDIA driver is reasonably recent (570+).
echo                 Recommended default if your driver is up to date.
echo.
echo   2. CUDA 12  - For older or not-recently-updated NVIDIA drivers.
echo                 Will NOT work on RTX 50-series (Blackwell) GPUs.
echo                 Use this if you can't or don't want to update your driver.
echo.
echo   If unsure, run "nvidia-smi" in a Command Prompt to see your driver
echo   version and max supported CUDA version, then pick accordingly.
echo.
set "CUDACHOICE="
set /p CUDACHOICE="Enter 1 or 2: "

if "%CUDACHOICE%"=="1" (
    set "URL=https://github.com/Comfy-Org/ComfyUI/releases/latest/download/ComfyUI_windows_portable_nvidia.7z"
    set "ARCHIVE=ComfyUI_windows_portable_nvidia.7z"
) else if "%CUDACHOICE%"=="2" (
    set "URL=https://github.com/Comfy-Org/ComfyUI/releases/latest/download/ComfyUI_windows_portable_nvidia_cu126.7z"
    set "ARCHIVE=ComfyUI_windows_portable_nvidia_cu126.7z"
) else (
    echo Invalid choice, please enter 1 or 2.
    goto ask_cuda
)

set "DL_PATH=%TEMP%\%ARCHIVE%"

:: ---------------------------------------------------------------------
:: 3. Download the archive
:: ---------------------------------------------------------------------
echo.
echo Downloading %ARCHIVE% ...
echo   From: %URL%
echo   To:   %DL_PATH%
echo This may take a while depending on your connection.
echo.

curl -L --fail -o "%DL_PATH%" "%URL%"
if errorlevel 1 (
    echo.
    echo ERROR: Download failed. Check your internet connection and try again.
    pause
    exit /b 1
)

:: ---------------------------------------------------------------------
:: 4. Make sure 7-Zip is available (install via winget if missing)
:: ---------------------------------------------------------------------
set "SEVENZIP=7z"
where 7z >nul 2>nul
if errorlevel 1 (
    echo.
    echo 7-Zip not found on PATH. Installing via winget...
    winget install --id 7zip.7zip -e --accept-package-agreements --accept-source-agreements
    :: winget-installed apps aren't always on PATH in the current session
    set "PATH=%PATH%;%ProgramFiles%\7-Zip"
    set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
    if not exist "!SEVENZIP!" (
        echo.
        echo ERROR: Could not find 7z.exe after installation.
        echo Please install 7-Zip manually and re-run this script.
        pause
        exit /b 1
    )
)

:: ---------------------------------------------------------------------
:: 5. Extract archive to the chosen drive
:: ---------------------------------------------------------------------
echo.
echo Extracting to %INSTALL_ROOT% ...
"!SEVENZIP!" x "%DL_PATH%" -o"%INSTALL_ROOT%" -y
if errorlevel 1 (
    echo.
    echo ERROR: Extraction failed.
    pause
    exit /b 1
)

:: ---------------------------------------------------------------------
:: 6. Rename ComfyUI_windows_portable -> ComfyUI
:: ---------------------------------------------------------------------
if exist "%COMFY_ROOT%" (
    echo.
    echo "%COMFY_ROOT%" already exists, skipping rename step.
) else (
    if exist "%INSTALL_ROOT%ComfyUI_windows_portable" (
        echo Renaming ComfyUI_windows_portable to ComfyUI ...
        ren "%INSTALL_ROOT%ComfyUI_windows_portable" "ComfyUI"
    ) else (
        echo.
        echo ERROR: Expected folder "%INSTALL_ROOT%ComfyUI_windows_portable" not found after extraction.
        pause
        exit /b 1
    )
)

:: ---------------------------------------------------------------------
:: 7. Install Git
:: ---------------------------------------------------------------------
echo.
echo Installing Git ...
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
:: Make sure git is usable in this session even if PATH hasn't refreshed yet
set "PATH=%PATH%;%ProgramFiles%\Git\cmd"
where git >nul 2>nul
if errorlevel 1 (
    echo.
    echo WARNING: git is not available in this session's PATH yet.
    echo Close this window, open a NEW Command Prompt, and re-run this script
    echo to continue from the clone step, or add Git to PATH manually.
    pause
    exit /b 1
)

:: ---------------------------------------------------------------------
:: 8. Clone custom node pack
:: ---------------------------------------------------------------------
set "CUSTOM_NODES=%COMFY_ROOT%\ComfyUI\custom_nodes"
if not exist "%CUSTOM_NODES%" (
    echo.
    echo ERROR: "%CUSTOM_NODES%" does not exist. Cannot clone node pack.
    pause
    exit /b 1
)

echo.
echo Cloning ComfyUI_Ole_NodePack ...
pushd "%CUSTOM_NODES%"
git clone https://github.com/Arnold2006/ComfyUI_Ole_NodePack.git
popd

echo.
echo Cloning rgthree-comfy ...
pushd "%CUSTOM_NODES%"
git clone https://github.com/rgthree/rgthree-comfy.git
popd

echo.
echo Cloning CRT-Nodes ...
pushd "%CUSTOM_NODES%"
git clone https://github.com/PGCRT/CRT-Nodes.git
popd

:: ---------------------------------------------------------------------
:: 9. Install requirements for each custom node pack
:: ---------------------------------------------------------------------
set "PY_EMBED=%COMFY_ROOT%\python_embeded\python.exe"

for %%N in (ComfyUI_Ole_NodePack rgthree-comfy CRT-Nodes) do (
    set "NODE_REQS=%CUSTOM_NODES%\%%N\requirements.txt"
    echo.
    if exist "!NODE_REQS!" (
        echo Installing %%N requirements ...
        "%PY_EMBED%" -m pip install -r "!NODE_REQS!"
    ) else (
        echo %%N has no requirements.txt, skipping.
    )
)

:: ---------------------------------------------------------------------
:: 10. Install ComfyUI-Manager requirements
:: ---------------------------------------------------------------------
set "MANAGER_REQS=%COMFY_ROOT%\ComfyUI\manager_requirements.txt"

echo.
if exist "%MANAGER_REQS%" (
    echo Installing ComfyUI-Manager requirements ...
    "%PY_EMBED%" -m pip install -r "%MANAGER_REQS%"
) else (
    echo WARNING: "%MANAGER_REQS%" not found, skipping.
)

:: ---------------------------------------------------------------------
:: 11. Patch run_nvidia_gpu.bat first line
:: ---------------------------------------------------------------------
set "RUNBAT=%COMFY_ROOT%\run_nvidia_gpu.bat"

echo.
if exist "%RUNBAT%" (
    echo Updating %RUNBAT% ...
    set "TMP_RUNBAT=%RUNBAT%.tmp"
    > "!TMP_RUNBAT!" echo .\python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build --enable-manager
    for /f "usebackq skip=1 delims=" %%L in ("%RUNBAT%") do (
        >> "!TMP_RUNBAT!" echo %%L
    )
    move /y "!TMP_RUNBAT!" "%RUNBAT%" >nul
    echo Done.
) else (
    echo WARNING: "%RUNBAT%" not found, could not patch it.
)

:: ---------------------------------------------------------------------
:: 12. Optional: download Ideogram 4 models
:: ---------------------------------------------------------------------
echo.
echo Ideogram 4 requires several large model files (many GB total):
echo   - vae:              flux2-vae.safetensors
echo   - diffusion_models:  ideogram4_fp8_scaled.safetensors
echo                        ideogram4_unconditional_fp8_scaled.safetensors
echo   - text_encoders:     qwen3vl_8b_fp8_scaled.safetensors
echo                        gemma4_e4b_it_fp8_scaled.safetensors
echo.
set "GETMODELS="
set /p GETMODELS="Download the Ideogram 4 models now? (Y/N): "

if /i "%GETMODELS%"=="Y" (
    set "MODELS_ROOT=%COMFY_ROOT%\ComfyUI\models"

    if not exist "!MODELS_ROOT!\vae" mkdir "!MODELS_ROOT!\vae"
    if not exist "!MODELS_ROOT!\diffusion_models" mkdir "!MODELS_ROOT!\diffusion_models"
    if not exist "!MODELS_ROOT!\text_encoders" mkdir "!MODELS_ROOT!\text_encoders"

    call :download_model "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors" "!MODELS_ROOT!\vae\flux2-vae.safetensors"
    call :download_model "https://huggingface.co/Comfy-Org/Ideogram-4/resolve/main/diffusion_models/ideogram4_fp8_scaled.safetensors" "!MODELS_ROOT!\diffusion_models\ideogram4_fp8_scaled.safetensors"
    call :download_model "https://huggingface.co/Comfy-Org/Ideogram-4/resolve/main/diffusion_models/ideogram4_unconditional_fp8_scaled.safetensors" "!MODELS_ROOT!\diffusion_models\ideogram4_unconditional_fp8_scaled.safetensors"
    call :download_model "https://huggingface.co/Comfy-Org/Qwen3-VL/resolve/main/text_encoders/qwen3vl_8b_fp8_scaled.safetensors" "!MODELS_ROOT!\text_encoders\qwen3vl_8b_fp8_scaled.safetensors"
    call :download_model "https://huggingface.co/Comfy-Org/gemma-4/resolve/main/text_encoders/gemma4_e4b_it_fp8_scaled.safetensors" "!MODELS_ROOT!\text_encoders\gemma4_e4b_it_fp8_scaled.safetensors"

    echo.
    echo Ideogram 4 model download step finished.
) else (
    echo Skipping Ideogram 4 model download.
)

:: ---------------------------------------------------------------------
:: 13. Optional: download Ideogram 4 workflow
:: ---------------------------------------------------------------------
echo.
echo An Ideogram 4 ComfyUI workflow (Ideogram-4-V3.json) is available.
echo It will be placed into user\default\workflows so it shows up in ComfyUI.
echo.
set "GETWORKFLOW="
set /p GETWORKFLOW="Download the Ideogram 4 workflow now? (Y/N): "

if /i "%GETWORKFLOW%"=="Y" (
    set "WORKFLOWS_DIR=%COMFY_ROOT%\ComfyUI\user\default\workflows"
    if not exist "!WORKFLOWS_DIR!" mkdir "!WORKFLOWS_DIR!"
    call :download_model "https://raw.githubusercontent.com/Arnold2006/Ideogram_Workflow/main/Ideogram-4-V3.json" "!WORKFLOWS_DIR!\Ideogram-4-V3.json"

    echo.
    echo Ideogram 4 workflow download step finished.
) else (
    echo Skipping Ideogram 4 workflow download.
)

:: ---------------------------------------------------------------------
:: Done
:: ---------------------------------------------------------------------
echo.
echo =======================================================
echo  ComfyUI installation complete at %COMFY_ROOT%
echo =======================================================
echo.
del /q "%DL_PATH%" >nul 2>nul
pause
exit /b 0

:: ---------------------------------------------------------------------
:: Helper: download a model file, skip if it already exists
:: Usage: call :download_model "<url>" "<destination path>"
:: ---------------------------------------------------------------------
:download_model
set "MODEL_URL=%~1"
set "MODEL_DEST=%~2"
if exist "%MODEL_DEST%" (
    echo.
    echo Already exists, skipping: %MODEL_DEST%
    goto :eof
)
echo.
echo Downloading: %~nx2
curl -L --fail -o "%MODEL_DEST%" "%MODEL_URL%"
if errorlevel 1 (
    echo WARNING: Failed to download %~nx2. You can re-run this script or download it manually.
)
goto :eof