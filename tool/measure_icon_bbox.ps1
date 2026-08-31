# Mide la caja (bounding box) del isotipo dentro de una imagen de icono.
# Sirve para verificar que el logo cae dentro de la zona segura del adaptive
# icon y que las escalas del generador son las esperadas.
#
# Uso, desde la raiz de flutter_app_saludable:
#   powershell -ExecutionPolicy Bypass -File tool/measure_icon_bbox.ps1 <ruta.png> [<ruta.png> ...]

param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Paths)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

foreach ($path in $Paths) {
    $full = (Resolve-Path $path).Path
    $bmp  = [System.Drawing.Bitmap]::FromFile($full)
    try {
        $minX = [int]::MaxValue; $maxX = -1
        $minY = [int]::MaxValue; $maxY = -1

        for ($y = 0; $y -lt $bmp.Height; $y++) {
            for ($x = 0; $x -lt $bmp.Width; $x++) {
                $c = $bmp.GetPixel($x, $y)
                # Pixel "del logo": opaco y claramente mas oscuro que el blanco.
                if ($c.A -gt 16 -and (($c.R -lt 235) -or ($c.G -lt 235) -or ($c.B -lt 235))) {
                    if ($x -lt $minX) { $minX = $x }
                    if ($x -gt $maxX) { $maxX = $x }
                    if ($y -lt $minY) { $minY = $y }
                    if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }

        if ($maxX -lt 0) {
            Write-Host "$path : lienzo $($bmp.Width)x$($bmp.Height)  SIN PIXELES DE LOGO"
            continue
        }

        $w  = $maxX - $minX + 1
        $h  = $maxY - $minY + 1
        $cx = [int](($minX + $maxX) / 2)
        $cy = [int](($minY + $maxY) / 2)
        Write-Host "$path : lienzo $($bmp.Width)x$($bmp.Height)  caja del isotipo ${w}x${h}  centro ${cx},${cy}"
    }
    finally {
        $bmp.Dispose()
    }
}
