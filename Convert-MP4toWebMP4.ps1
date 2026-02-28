# ============================================================
#  Convert-MP4toWebMP4.ps1
#  Re-codifica archivos .MP4 a H264/AAC optimizado para web
#  (navegador): faststart, yuv420p, AAC stereo.
#  - Si el video es > 1080p lo escala a 1080p (usa -Keep4K para evitarlo).
#  - Selecciona pista de audio en espanol (spa/es/esp).
#    Fallback a primera pista si no hay espanol.
#  - Quema subtitulos .SRT si existe uno con el mismo nombre.
#  - Para videos 4K usa preset "faster" automaticamente para acelerar.
#  - Soporte de aceleracion por hardware GPU (NVENC/QSV/AMF) opcional.
#
#  Uso:
#    .\Convert-MP4toWebMP4.ps1
#    .\Convert-MP4toWebMP4.ps1 -InputFolder "D:\Videos" -OutputFolder "D:\Web" -CRF 20
#    .\Convert-MP4toWebMP4.ps1 -Keep4K              <- no escala a 1080p
#    .\Convert-MP4toWebMP4.ps1 -HWAccel nvidia      <- usa GPU NVIDIA (NVENC)
#    .\Convert-MP4toWebMP4.ps1 -HWAccel intel       <- usa GPU Intel (QSV)
#    .\Convert-MP4toWebMP4.ps1 -HWAccel amd         <- usa GPU AMD (AMF)
#
#  Requisitos: ffmpeg.exe y ffprobe.exe en la misma carpeta, o en el PATH.
# ============================================================

[CmdletBinding()]
param(
    [string]$InputFolder  = "",
    [string]$OutputFolder = "",
    [int]$CRF             = 22,
    [string]$Preset       = "medium",
    [switch]$Keep4K,
    [ValidateSet("","nvidia","intel","amd")]
    [string]$HWAccel      = "",
    [switch]$Overwrite,
    [switch]$Recurse
)

# -- Resolucion de rutas
$ScriptDir = if ($PSScriptRoot -and $PSScriptRoot -ne "") {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    (Get-Location).Path
}

if (-not $InputFolder)  { $InputFolder  = $ScriptDir }
if (-not $OutputFolder) { $OutputFolder = Join-Path $InputFolder "converted" }

if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    Write-Host "[INFO] Carpeta de salida creada: $OutputFolder" -ForegroundColor Cyan
}

# -- Verificar ffmpeg
$ffmpegExe   = $null
$localFfmpeg = Join-Path $ScriptDir "ffmpeg.exe"
if (Test-Path $localFfmpeg) {
    $ffmpegExe = $localFfmpeg
    Write-Host "[INFO] ffmpeg: $ffmpegExe" -ForegroundColor Cyan
} elseif (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    $ffmpegExe = (Get-Command ffmpeg).Source
    Write-Host "[INFO] ffmpeg en PATH: $ffmpegExe" -ForegroundColor Cyan
} else {
    Write-Error "ffmpeg no encontrado. Coloca ffmpeg.exe junto al script o anyadelo al PATH."
    exit 1
}

# -- Verificar ffprobe
$ffprobeExe = $null
$localProbe = Join-Path $ScriptDir "ffprobe.exe"
if (Test-Path $localProbe) {
    $ffprobeExe = $localProbe
} elseif (Get-Command ffprobe -ErrorAction SilentlyContinue) {
    $ffprobeExe = (Get-Command ffprobe).Source
} else {
    Write-Error "ffprobe no encontrado. Es necesario para detectar streams."
    exit 1
}

# -- Configuracion de aceleracion GPU
switch ($HWAccel.ToLower()) {
    "nvidia" {
        $videoEncoder = "h264_nvenc"
        $qualityArg   = "-qp $CRF -preset p4"
        Write-Host "[GPU]   Aceleracion NVIDIA NVENC activada." -ForegroundColor Magenta
    }
    "intel"  {
        $videoEncoder = "h264_qsv"
        $qualityArg   = "-q $CRF"
        Write-Host "[GPU]   Aceleracion Intel QSV activada." -ForegroundColor Magenta
    }
    "amd"    {
        $videoEncoder = "h264_amf"
        $qualityArg   = "-qp_i $CRF -qp_p $CRF -qp_b $CRF -vbaq 0"
        Write-Host "[GPU]   Aceleracion AMD AMF activada." -ForegroundColor Magenta
    }
    default  {
        $videoEncoder = "libx264"
        $qualityArg   = "-crf $CRF"
        Write-Host "[CPU]   Codificacion por CPU (libx264)." -ForegroundColor Cyan
    }
}

# -- Funcion: devuelve el indice de stream de la primera pista de audio en espanol, o -1
function Get-SpanishAudioIndex {
    param([string]$FilePath)
    $probeArgs = "-v quiet -select_streams a -show_entries stream=index:stream_tags=language -of csv=p=0 `"$FilePath`""
    $lines = & cmd.exe /c "`"$script:ffprobeExe`" $probeArgs" 2>$null
    $streamIndex = 0
    foreach ($line in $lines) {
        $lang = ($line -split ',')[-1].Trim().ToLower()
        if ($lang -eq "spa" -or $lang -eq "es" -or $lang -eq "esp") {
            return $streamIndex
        }
        $streamIndex++
    }
    return -1
}

# -- Funcion: devuelve el ancho del video en pixels
function Get-VideoWidth {
    param([string]$FilePath)
    $probeArgs = "-v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 `"$FilePath`""
    $raw = & cmd.exe /c "`"$script:ffprobeExe`" $probeArgs" 2>$null
    $w = ($raw | Where-Object { $_ -match '\d' } | Select-Object -First 1) -replace '[^\d]', ''
    Write-Host "[DEBUG] ffprobe ancho raw=[$raw] limpio=[$w]" -ForegroundColor DarkGray
    if ($w -match '^\d+$') { return [int]$w } else { return 0 }
}

# -- Buscar archivos MP4 (excluye la carpeta de salida para no reprocesar)
$mp4Files = Get-ChildItem -Path $InputFolder -Filter "*.mp4" -Recurse:$Recurse -File |
            Where-Object { $_.DirectoryName -ine $OutputFolder }

if ($mp4Files.Count -eq 0) {
    Write-Host "[AVISO] No se encontraron archivos .MP4 en: $InputFolder" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  MP4 -> MP4 H264 optimizado para web"  -ForegroundColor Green
Write-Host "  Audio: espanol (fallback: pista 1)"   -ForegroundColor Green
Write-Host "  Subs:  quema .SRT si existe"          -ForegroundColor Green
Write-Host "  4K:    $(if ($Keep4K) { 'se mantiene' } else { 'se escala a 1080p (faster)' })" -ForegroundColor Green
Write-Host "  Archivos encontrados: $($mp4Files.Count)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$okCount = $skipCount = $errorCount = 0

foreach ($mp4 in $mp4Files) {
    $baseName  = $mp4.BaseName
    $outputMp4 = Join-Path $OutputFolder "$baseName.mp4"

    Write-Host "----------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[VIDEO] $($mp4.FullName)" -ForegroundColor White

    if ((Test-Path $outputMp4) -and -not $Overwrite) {
        Write-Host "[SKIP]  Ya existe el archivo de salida. Usa -Overwrite para sobreescribir." -ForegroundColor Yellow
        $skipCount++
        continue
    }

    # -- Detectar resolucion y decidir escala y preset
    $videoWidth = Get-VideoWidth -FilePath $mp4.FullName
    $is4K       = $videoWidth -gt 1920

    if ($is4K -and -not $Keep4K) {
        Write-Host "[RES]   4K detectado ($videoWidth px) -> escalando a 1080p (preset: faster)" -ForegroundColor Magenta
        $activePreset = "faster"
        $levelArg     = "4.1"
        $scaleArg     = "scale=-2:1080"
    } elseif ($is4K -and $Keep4K) {
        Write-Host "[RES]   4K detectado ($videoWidth px) -> manteniendo 4K (nivel 5.1)" -ForegroundColor Magenta
        $activePreset = $Preset
        $levelArg     = "5.1"
        $scaleArg     = ""
    } else {
        Write-Host "[RES]   $videoWidth px -> manteniendo resolucion (nivel 4.1)" -ForegroundColor Cyan
        $activePreset = $Preset
        $levelArg     = "4.1"
        $scaleArg     = ""
    }

    # -- Detectar pista de audio en espanol
    $spaIndex = Get-SpanishAudioIndex -FilePath $mp4.FullName
    if ($spaIndex -ge 0) {
        Write-Host "[AUDIO] Pista en espanol encontrada (stream $spaIndex)" -ForegroundColor Cyan
        $audioMap = "-map 0:v:0 -map 0:a:$spaIndex"
    } else {
        Write-Host "[AUDIO] Sin pista en espanol -> usando primera pista de audio." -ForegroundColor DarkYellow
        $audioMap = "-map 0:v:0 -map 0:a:0"
    }

    # -- Buscar .SRT con el mismo nombre (insensible a mayusculas)
    $srtFile = Get-ChildItem -Path $mp4.DirectoryName -File |
               Where-Object { $_.BaseName -ieq $baseName -and $_.Extension -ieq ".srt" } |
               Select-Object -First 1

    $overwriteFlag = if ($Overwrite) { "-y" } else { "-n" }

    # -- Construir filtro de video (scale y/o subtitulos encadenados)
    if ($srtFile) {
        Write-Host "[SRT]   Encontrado: $($srtFile.FullName)" -ForegroundColor Cyan
        $srtEscaped = $srtFile.FullName -replace '\\','/' -replace ':','\:'
        $subFilter  = "subtitles='${srtEscaped}':force_style='FontName=Arial,FontSize=22,PrimaryColour=&Hffffff,OutlineColour=&H000000,BorderStyle=1,Outline=2'"
        if ($scaleArg) {
            $vfArg = "-vf `"${scaleArg},${subFilter}`""
        } else {
            $vfArg = "-vf `"${subFilter}`""
        }
    } else {
        Write-Host "[SRT]   No encontrado -> sin subtitulos quemados." -ForegroundColor DarkYellow
        if ($scaleArg) {
            $vfArg = "-vf `"${scaleArg}`""
        } else {
            $vfArg = ""
        }
    }

    $presetArg = if ($videoEncoder -eq "libx264") { "-preset $activePreset" } else { "" }

    $inputArgs  = "-analyzeduration 200M -probesize 200M -ignore_unknown"
    $outputArgs = "-c:v $videoEncoder $qualityArg $presetArg -profile:v high -level $levelArg -pix_fmt yuv420p " +
                  "-c:a aac -b:a 192k -ac 2 -async 1 " +
                  "-fps_mode vfr -movflags +faststart -map_metadata -1"

    $cmdArgs = "-hide_banner -loglevel error -stats " +
               "$inputArgs -i `"$($mp4.FullName)`" " +
               "$audioMap $vfArg " +
               "$outputArgs " +
               "$overwriteFlag `"$outputMp4`""

    Write-Host "[CMD]   `"$ffmpegExe`" $cmdArgs" -ForegroundColor DarkGray

    $t0      = Get-Date
    $process = Start-Process -FilePath "cmd.exe" `
                             -ArgumentList "/c `"`"$ffmpegExe`" $cmdArgs`"" `
                             -NoNewWindow -Wait -PassThru
    $elapsed = (Get-Date) - $t0

    if ($process.ExitCode -eq 0) {
        $sizeMBIn  = [math]::Round($mp4.Length / 1MB, 2)
        $sizeMBOut = [math]::Round((Get-Item $outputMp4).Length / 1MB, 2)
        $reduction = [math]::Round((1 - $sizeMBOut / $sizeMBIn) * 100, 1)
        Write-Host "[OK]    $([math]::Round($elapsed.TotalSeconds,1))s | $sizeMBIn MB -> $sizeMBOut MB ($reduction% reduccion) -> $outputMp4" -ForegroundColor Green
        $okCount++
    } else {
        Write-Host "[ERROR] ffmpeg codigo $($process.ExitCode) en: $($mp4.Name)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  RESUMEN"                               -ForegroundColor Green
Write-Host "  Convertidos : $okCount"                -ForegroundColor Green
Write-Host "  Omitidos    : $skipCount"              -ForegroundColor Yellow
Write-Host "  Errores     : $errorCount"             -ForegroundColor $(if ($errorCount) { "Red" } else { "Green" })
Write-Host "  Salida      : $OutputFolder"           -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Green

# -- Apagar el ordenador al finalizar
Write-Host "" -ForegroundColor Green
Write-Host "[INFO] Apagando el ordenador en 60 segundos... (shutdown /a para cancelar)" -ForegroundColor Yellow
shutdown /s /t 60 /c "Conversion finalizada. Apagando en 60 segundos."
