# Comfy ComfyUI
A comfy Windows portable ComfyUI installer :-)

The script simplifies installing the portable version of ComfyUI to executing a single .bat file, including preserving your models and activating the manager.

# Instructions
1. Place the .bat file in an empty folder and run it :-)
2. Start ComfyUI by simply running the .bat file in the created folder :-)
_And then?_
- Place all your models in the central models folder from now on :-)
- Run the script every time a new portable version is available :-)
- Simply delete old versions by deleting the folder :-)

# What the script does step by step:
1. It searches for the latest ComfyUI Portable version from https://github.com/Comfy-Org/ComfyUI/releases and checks if this version number is already installed in the folder where the script is run.
2. If not, you select your CPU/GPU, and the latest version will be downloaded and extracted to a folder with the version number as the folder name.
3. If there isn't already a "models" folder in the script's folder, it configures ComfyUI via the extra_model_paths.yaml file so that all models (such as checkpoints, LoRAs, and VAEs) are stored in this central location.
4. Activates the ComfyUI manager and cleans up its own install files.

Requirements:
Visual C++ Redistributable Runtimes All-in-One must be installed.
