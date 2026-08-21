# ComfyUI_Portable_Install_Script

A Windows batch script that automates installing the portable build of [ComfyUI](https://github.com/Comfy-Org/ComfyUI), along with a set of custom node packs, their dependencies, and optional extra models/workflows.

## What `Portable_Comfy_Install.bat` does

Running the script walks you through the following steps:

1. **Choose an install drive** — prompts for a drive letter (e.g. `D`) and installs to `<Drive>:\ComfyUI`. Warns and asks for confirmation if that folder already exists.
2. **Choose a CUDA build** — lets you pick between:
   - **CUDA 13** — required for RTX 50-series (Blackwell) GPUs, also works on RTX 20/30/40-series with a reasonably recent (570+) NVIDIA driver. Recommended default.
   - **CUDA 12** — for older or less up-to-date NVIDIA drivers; does not work on RTX 50-series GPUs.
3. **Download** the chosen ComfyUI portable archive (`.7z`) from the official [Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI) releases using `curl`.
4. **Ensure 7-Zip is available**, installing it via `winget` if it isn't already on the `PATH`.
5. **Extract** the downloaded archive to the chosen drive.
6. **Rename** the extracted `ComfyUI_windows_portable` folder to `ComfyUI`.
7. **Install Git** via `winget` if it's not already available.
8. **Clone custom node packs** into `ComfyUI\custom_nodes`:
   - [ComfyUI_Ole_NodePack](https://github.com/Arnold2006/ComfyUI_Ole_NodePack)
   - [rgthree-comfy](https://github.com/rgthree/rgthree-comfy)
   - [CRT-Nodes](https://github.com/PGCRT/CRT-Nodes)
9. **Install requirements** for each cloned custom node pack using the embedded Python (`python_embeded\python.exe`).
10. **Install ComfyUI-Manager requirements** (`manager_requirements.txt`).
11. **Patch `run_nvidia_gpu.bat`** to launch ComfyUI with the `--enable-manager` flag.
12. **Optionally download the Ideogram 4 model files** (VAE, diffusion models, and text encoders) into the appropriate `models` subfolders, skipping any files that already exist.
13. **Optionally download the Ideogram 4 workflow** (`Ideogram-4-V3.json`) into `ComfyUI\user\default\workflows`.

At the end, the script cleans up the downloaded archive and reports the install location.

## Requirements

- Windows with `curl` available (included by default on modern Windows).
- Internet access to GitHub, Hugging Face, and `winget` package sources.
- Enough free disk space on the target drive for the ComfyUI portable build and any optional models (the Ideogram 4 models are several GB in total).

## Usage

1. Download `Portable_Comfy_Install.bat`.
2. Run it (double-click, or run from a Command Prompt).
3. Follow the prompts to choose a drive and CUDA build, and answer the optional download prompts.
4. Once complete, launch ComfyUI using `run_nvidia_gpu.bat` inside the installed `ComfyUI` folder.