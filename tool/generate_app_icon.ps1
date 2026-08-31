# Genera las imagenes fuente del icono de la app a partir del isotipo aprobado
# de Play Store (assets/icon/source_isotipo_512.png).
#
#   assets/icon/app_icon.png             1024x1024, isotipo con R/W = 0.40
#                                        (icono legacy de Android + iOS)
#   assets/icon/app_icon_foreground.png  1024x1024, isotipo con R/W = 0.30,
#                                        dentro de la zona segura del adaptive
#                                        icon (circulo de 66dp sobre 108dp)
#
# Uso, desde la raiz de flutter_app_saludable:
#   powershell -ExecutionPolicy Bypass -File tool/generate_app_icon.ps1
#
# Requiere Windows (System.Drawing). Si algun dia hace falta en CI/Linux,
# reescribir con package:image de Dart.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot   = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot 'assets\icon\source_isotipo_512.png'

if (-not (Test-Path $sourcePath)) {
    throw "No se encuentra la imagen fuente: $sourcePath"
}

# Medidas del isotipo dentro de source_isotipo_512.png (umbral < 235 por canal).
$Canvas    = 1024
$SrcX      = 134
$SrcY      = 153
$SrcW      = 245
$SrcH      = 221
$SrcRadius = 162.9   # distancia maxima del centro de la caja a un pixel del logo

$src = [System.Drawing.Bitmap]::FromFile($sourcePath)

function New-IconPng {
    param(
        [Parameter(Mandatory)][string]$OutPath,
        [Parameter(Mandatory)][double]$TargetRadiusFraction
    )

    $scale = ($TargetRadiusFraction * $Canvas) / $SrcRadius
    $dw = [int][math]::Round($SrcW * $scale)
    $dh = [int][math]::Round($SrcH * $scale)
    $dx = [int][math]::Round(($Canvas - $dw) / 2)
    $dy = [int][math]::Round(($Canvas - $dh) / 2)

    $bmp = New-Object System.Drawing.Bitmap(
        $Canvas, $Canvas,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.Clear([System.Drawing.Color]::White)
        $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        $srcRect  = New-Object System.Drawing.Rectangle($SrcX, $SrcY, $SrcW, $SrcH)
        $destRect = New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)
        $g.DrawImage($src, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally {
        $g.Dispose()
    }

    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "$OutPath  ->  isotipo ${dw}x${dh} en lienzo ${Canvas}x${Canvas}"
}

try {
    New-IconPng -OutPath (Join-Path $repoRoot 'assets\icon\app_icon.png') `
                -TargetRadiusFraction 0.40
    New-IconPng -OutPath (Join-Path $repoRoot 'assets\icon\app_icon_foreground.png') `
                -TargetRadiusFraction 0.30
}
finally {
    $src.Dispose()
}
