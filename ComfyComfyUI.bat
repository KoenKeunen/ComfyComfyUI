@echo off
TITLE ComfyUI Auto-Installer
echo Starting Comfy Windows Portable ComfyUI Installation Script v0.9
echo.

:: Extract PowerShell script to temp file
set "PSTemp=%TEMP%\install_comfy_%RANDOM%.ps1"

:: ----------------------------------------------------------
:: EXTRACT POWERSHELL SCRIPT
:: ----------------------------------------------------------
:: The number in 'more +N' below must strictly match the number of lines in this header block.
:: We calculate it dynamically in the generator to ensure it is correct.
more +31 "%~f0" > "%PSTemp%"

:: ----------------------------------------------------------
:: EXECUTE
:: ----------------------------------------------------------
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%PSTemp%"

:: ----------------------------------------------------------
:: CLEANUP
:: ----------------------------------------------------------
if exist "%PSTemp%" del "%PSTemp%"

echo.
echo ========================================================
echo Script Finished.
echo ========================================================
pause
goto :EOF

# ----------------------------------------------------------
# ComfyUI Auto-Updater Logic
# ----------------------------------------------------------
$ErrorActionPreference = "Stop"

# Ensure security protocols for GitHub (TLS 1.2+)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step {
    param([string]$Message)
    Write-Host -ForegroundColor Cyan ">> $Message"
}

function Write-Success {
    param([string]$Message)
    Write-Host -ForegroundColor Green "SUCCESS: $Message"
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host -ForegroundColor Red "ERROR: $Message"
}

# Optimized Download Function using .NET HttpClient for speed and progress
function Download-FileWithProgress {
    param([string]$Url, [string]$Dest)
    
    Write-Host "Initializing download..." -ForegroundColor Gray
    
    try {
        # Fix: Explicitly load System.Net.Http assembly to avoid "Cannot find type" error
        Add-Type -AssemblyName System.Net.Http
        
        $httpClient = New-Object System.Net.Http.HttpClient
        $httpClient.Timeout = [TimeSpan]::FromMinutes(60) # Large timeout for slow connections
        $httpClient.DefaultRequestHeaders.Add("User-Agent", "ComfyUI-Auto-Installer")
        
        # Get headers first
        $response = $httpClient.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        
        if (-not $response.IsSuccessStatusCode) {
            throw "HTTP Error: $($response.StatusCode)"
        }
        
        $totalBytes = $response.Content.Headers.ContentLength
        if ($null -eq $totalBytes) { $totalBytes = 0 }
        
        $totalMB = [math]::Round($totalBytes / 1MB, 2)
        Write-Host "File Size: $totalMB MB" -ForegroundColor White
        Write-Host "Source: $Url" -ForegroundColor Gray
        
        $stream = $response.Content.ReadAsStreamAsync().Result
        $fileStream = [System.IO.File]::Create($Dest)
        
        $bufferSize = 81920 # 80KB buffer
        $buffer = New-Object byte[] $bufferSize
        $totalRead = 0
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        
        $lastUpdate = 0
        
        while ($true) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read
            
            # Update UI periodically
            if ($totalBytes -gt 0) {
                if ($watch.ElapsedMilliseconds - $lastUpdate -gt 200) {
                    $percent = [math]::Round(($totalRead / $totalBytes) * 100, 1)
                    $downloadedMB = [math]::Round($totalRead / 1MB, 2)
                    
                    Write-Progress -Activity "Downloading..." -Status "$percent% ($downloadedMB / $totalMB MB)" -PercentComplete $percent
                    $lastUpdate = $watch.ElapsedMilliseconds
                }
            } else {
                 # Indeterminate
                 $downloadedMB = [math]::Round($totalRead / 1MB, 2)
                 if ($watch.ElapsedMilliseconds - $lastUpdate -gt 500) {
                    Write-Progress -Activity "Downloading..." -Status "$downloadedMB MB downloaded"
                    $lastUpdate = $watch.ElapsedMilliseconds
                 }
            }
        }
        
        $fileStream.Close()
        $stream.Close()
        $httpClient.Dispose()
        $watch.Stop()
        
        Write-Progress -Activity "Downloading..." -Completed
        Write-Host "Download finished in $($watch.Elapsed.ToString('mm\:ss'))" -ForegroundColor Green
    } catch {
        if ($fileStream) { $fileStream.Close() }
        if ($httpClient) { $httpClient.Dispose() }
        throw $_
    }
}

# 1. Fetch Latest Version
Write-Step "Checking for latest ComfyUI version from GitHub..."
try {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Comfy-Org/ComfyUI/releases/latest" -UseBasicParsing
    $versionTag = $latestRelease.tag_name
    Write-Host "Latest Version detected: $versionTag"
} catch {
    Write-ErrorMsg "Failed to fetch release info. Please check your internet connection."
    Write-Host "Details: $_"
    exit 1
}

$currentDir = Get-Location
$installDir = Join-Path $currentDir $versionTag

# 1A. Check if folder exists
if (Test-Path $installDir) {
    Write-Success "Version $versionTag is already installed in folder: $versionTag"
} else {

    # 1B. Logic for Download if not present
    Write-Host "Version $versionTag not found locally." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "--------------------------------------------------------"
    Write-Host "Which version would you like to install?" -ForegroundColor White
    Write-Host "--------------------------------------------------------"
    Write-Host "[1] NVIDIA (Recommended for most RTX/GTX cards)"
    Write-Host "[2] AMD (For Radeon GPUs)"
    Write-Host "[3] CPU Only (Slow, but works without dedicated GPU)"
    Write-Host ""

    $validChoice = $false
    $gpuKeyword = "nvidia"

    while (-not $validChoice) {
        $choice = Read-Host "Enter number [1-3]"
        switch ($choice) {
            '1' { $gpuKeyword = "nvidia"; $validChoice = $true }
            '2' { $gpuKeyword = "amd";    $validChoice = $true }
            '3' { $gpuKeyword = "cpu";    $validChoice = $true }
            Default { Write-Warning "Invalid selection. Please enter 1, 2, or 3." }
        }
    }

    Write-Step "Looking for portable asset for: $gpuKeyword"

    $downloadUrl = $null
    $assetName = $null

    # Search assets for keywords
    foreach ($asset in $latestRelease.assets) {
        if ($asset.name -match "portable" -and $asset.name -match $gpuKeyword) {
            $downloadUrl = $asset.browser_download_url
            $assetName = $asset.name
            break
        }
    }

    # Fallback 1: CPU special case
    if ($null -eq $downloadUrl -and $gpuKeyword -eq "cpu") {
        Write-Host "Specific CPU-only package not found. Looking for combined package..."
        foreach ($asset in $latestRelease.assets) {
            if ($asset.name -match "portable" -and $asset.name -match "cpu") {
                 $downloadUrl = $asset.browser_download_url
                 $assetName = $asset.name
                 break
            }
        }
    }

    # Fallback 2: General Fallback
    if ($null -eq $downloadUrl) {
        Write-Warning "Could not auto-detect a specific portable zip for '$gpuKeyword'. Attempting to find *any* portable zip..."
         foreach ($asset in $latestRelease.assets) {
            if ($asset.name -match "portable") {
                $downloadUrl = $asset.browser_download_url
                $assetName = $asset.name
                break
            }
        }
    }

    if ($null -eq $downloadUrl) {
         Write-ErrorMsg "No portable asset found in the latest release ($versionTag)."
         exit 1
    }

    # Correctly handle 7z extension
    $assetExtension = [System.IO.Path]::GetExtension($assetName)
    if (-not $assetExtension) { $assetExtension = ".zip" }
    $tempFileName = "comfy_temp" + $assetExtension
    $zipPath = Join-Path $currentDir $tempFileName

    Write-Step "Downloading $assetName..."

    try {
        # Use the custom .NET download function
        Download-FileWithProgress -Url $downloadUrl -Dest $zipPath
    } catch {
        Write-ErrorMsg "Download failed. $($_.Exception.Message)"
        exit 1
    }

    # 2. Unzip
    Write-Step "Unzipping to folder '$versionTag'..."

    # Logic to handle .7z if needed
    if ($assetExtension -match ".7z") {
        Write-Host "File is a 7-Zip archive." -ForegroundColor Gray
        
        # Check for 7z in PATH
        $7zCommand = $null
        if (Get-Command "7z" -ErrorAction SilentlyContinue) { $7zCommand = "7z" }
        elseif (Get-Command "7za" -ErrorAction SilentlyContinue) { $7zCommand = "7za" }
        
        if ($7zCommand) {
            try {
                & $7zCommand x "$zipPath" "-o$installDir" -y
            } catch {
                Write-ErrorMsg "7-Zip extraction failed. $($_.Exception.Message)"
                exit 1
            }
        } else {
            # 7-Zip not found, try to download standalone 7zr.exe
            Write-Host "7-Zip not found in PATH. Downloading standalone 7zr.exe for extraction..." -ForegroundColor Yellow
            $7zUrl = "https://www.7-zip.org/a/7zr.exe"
            $7zPath = Join-Path $currentDir "7zr.exe"
            
            try {
                 Invoke-WebRequest -Uri $7zUrl -OutFile $7zPath -UseBasicParsing
                 Write-Step "Extracting using 7zr.exe..."
                 & $7zPath x "$zipPath" "-o$installDir" -y
                 
                 # Cleanup 7zr
                 Remove-Item $7zPath -Force
            } catch {
                Write-ErrorMsg "Failed to download or run 7-Zip. Please install 7-Zip manually or extract the file yourself."
                Write-Host "File saved at: $zipPath"
                exit 1
            }
        }
    } else {
        # Assume standard zip
        try {
            Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
        } catch {
            Write-ErrorMsg "Extraction failed. $($_.Exception.Message)"
            exit 1
        }
    }

    # Cleanup archive
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    # ------------------------------------------------------------
    # 2B. Flatten Directory Structure
    # ------------------------------------------------------------
    # Often the portable zip extracts to "ComfyUI_windows_portable" inside our target folder.
    # We want to move contents UP one level so $installDir IS the Comfy folder.

    $nestedFolder = Join-Path $installDir "ComfyUI_windows_portable"
    if (Test-Path $nestedFolder) {
        Write-Step "Flattening directory structure..."
        try {
            # Move everything from nested folder to installDir
            Get-ChildItem -Path $nestedFolder | Move-Item -Destination $installDir -Force
            # Remove the now empty nested folder
            Remove-Item $nestedFolder -Force
        } catch {
            Write-Warning "Could not flatten directory structure completely. Please check folder contents manually."
        }
    }
}

# 3. Models Folder Logic
$doCheckModels = $true

if ($doCheckModels) {
    $mainModelsDir = Join-Path $currentDir "models"
    
    # After flattening, the structure should be $installDirComfyUImodels
    $internalComfyPath = Join-Path $installDir "ComfyUI"
    $internalModelsPath = Join-Path $internalComfyPath "models"

    if (Test-Path $internalModelsPath) {
        # Check if root models folder already exists
        if (Test-Path $mainModelsDir) {
            Write-Step "Central 'models' folder already exists. Keeping it."
            # We do NOT overwrite existing models.
        } else {
            Write-Step "Moving models folder from installation to root..."
            try {
                Move-Item -Path $internalModelsPath -Destination $mainModelsDir
            } catch {
                Write-ErrorMsg "Failed to move models folder. $($_.Exception.Message)"
            }
        }
        
        # Configure yaml
        $yamlExample = Join-Path $internalComfyPath "extra_model_paths.yaml.example"
        $yamlReal = Join-Path $internalComfyPath "extra_model_paths.yaml"
        
        if (Test-Path $yamlExample) {
            Write-Step "Renaming and configuring extra_model_paths.yaml..."
            try {
                # Rename the example file to the real file name
                Move-Item -Path $yamlExample -Destination $yamlReal -Force
                
                # Create the new configuration content
                # This points base_path to ../../ (the root where 'models' is moved to)
                # We overwrite with a complete, valid configuration to avoid regex issues.
                $newYamlContent = @"
comfyui:
    base_path: ../../
    checkpoints: models/checkpoints/
    text_encoders: models/text_encoders/
    clip_vision: models/clip_vision/
    configs: models/configs/
    controlnet: models/controlnet/
    diffusion_models: |
                 models/diffusion_models
                 models/unet
    embeddings: models/embeddings/
    loras: models/loras/
    upscale_models: models/upscale_models/
    vae: models/vae/
    audio_encoders: models/audio_encoders/
    model_patches: models/model_patches/
"@
                Set-Content -Path $yamlReal -Value $newYamlContent
            } catch {
                Write-Warning "Could not configure extra_model_paths.yaml. $($_.Exception.Message)"
            }
        }
    } else {
        # Silent fail if ComfyUI isn't structure as expected (maybe custom install)
    }
}

# ------------------------------------------------------------
# 4. Enable ComfyUI Manager (Native)
# ------------------------------------------------------------
Write-Step "Enabling Native ComfyUI Manager..."

$pythonRel = "python_embeded\python.exe"
$pythonPath = Join-Path $installDir $pythonRel
$reqsRel = "ComfyUI\manager_requirements.txt"
$reqsPath = Join-Path $installDir $reqsRel

if (Test-Path $pythonPath) {
    # 4A. Install Dependencies
    if (Test-Path $reqsPath) {
        Write-Step "Installing manager dependencies..."
        try {
            $proc = Start-Process -FilePath $pythonPath -ArgumentList "-m pip install -r `"$reqsPath`" -q" -WorkingDirectory $installDir -PassThru -NoNewWindow -Wait
            if ($proc.ExitCode -eq 0) {
                Write-Success "Manager dependencies installed."
            } else {
                Write-Warning "Pip install exited with code $($proc.ExitCode)."
            }
        } catch {
            Write-ErrorMsg "Failed to run pip install: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "manager_requirements.txt not found at $reqsPath"
    }

    # 4B. Patch Existing Run Scripts
    Write-Step "Patching existing run scripts to enable manager..."
    $runBats = Get-ChildItem -Path $installDir -Filter "run_*.bat"
    
    foreach ($bat in $runBats) {
        try {
            $txt = Get-Content -Path $bat.FullName -Raw
            # We look for the standard startup command and ensure --enable-manager is present
            if ($txt -match "--windows-standalone-build" -and $txt -notmatch "--enable-manager") {
                $newTxt = $txt -replace "--windows-standalone-build", "--windows-standalone-build --enable-manager"
                Set-Content -Path $bat.FullName -Value $newTxt
                Write-Host "Updated $($bat.Name) to include --enable-manager" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Could not patch $($bat.Name)"
        }
    }

} else {
    Write-Warning "Embedded Python not found. Skipping Manager setup."
}

# 5. Final Summary
Write-Success "Installation of ComfyUI Portable ($versionTag) complete."
Write-Host "Location: $installDir"
if (Test-Path "models") {
    Write-Host "Models are stored centrally in the 'models' folder."
}
