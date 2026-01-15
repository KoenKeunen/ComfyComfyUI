# Comfy ComfyUI
A comfy Windows portable ComfyUI installer :-)

The script simplifies installing the portable version of ComfyUI to executing a single .bat file which handles everything for you.

# Instructions
Requirements:
Visual C++ Redistributable Runtimes All-in-One must be installed.

1. Place the .bat file in an empty folder which will become your main ComfyUI folder.
2. run it :-)
3. Start ComfyUI by simply running the comfy .bat file of your choice in the newly created map.

_And then?_
- Place all your models in the central models folder from now on.
- Run the script every time a new portable version is available.
- Simply delete old ComfyUI versions by deleting their folder.

# What the script does step by step:
1. It searches for the latest ComfyUI Portable version from https://github.com/Comfy-Org/ComfyUI/releases and checks if this version number is already installed in the folder where the script is run.
2. If not, you select your CPU/GPU, and the latest version will be automatically downloaded and extracted to a folder with the version number as the folder name.
3. If there isn't already a "models" folder in the script's folder, it configures ComfyUI via the extra_model_paths.yaml file so that all models (such as checkpoints, LoRAs, and VAEs) are stored in this central location.
4. It activates the ComfyUI manager and cleans up its own install files.
