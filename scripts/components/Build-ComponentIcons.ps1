[CmdletBinding()]
param()
# Original vector paths, rendered with the Windows WPF renderer already used by
# CpStudio. No vendor image or runtime library is modified.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore,WindowsBase
$root = Join-Path $PSScriptRoot '../../src/cpstudio/components'
$icons = @(
    @{ Name='Burster2316'; Folder='V0.1'; Paths=@(
        'M 4,6 L 28,6 28,25 4,25 Z M 8,10 L 24,10 24,18 8,18 Z',
        'M 12,16 L 14,16 C 10,10 22,10 18,16 L 20,16',
        'M 8,22 L 10,22 M 15,22 L 17,22 M 22,22 L 24,22 M 8,25 L 8,28 M 24,25 L 24,28'
    ) },
    @{ Name='ForceTrace'; Folder='V0.2'; Paths=@(
        'M 5,4 L 5,27 29,27',
        'M 8,23 L 11,23 14,14 17,18 20,9 24,10 28,9',
        'M 9,6 L 13,6 M 9,10 L 11,10'
    ) },
    @{ Name='MachineCommon'; Folder='V0.1'; Paths=@(
        'M 5,5 L 27,5 27,27 5,27 Z M 16,5 L 16,27',
        'M 9,10 A 2,2 0 1 1 13,10 A 2,2 0 1 1 9,10',
        'M 8,20 A 3,3 0 0 1 14,20 M 11,20 L 13,17',
        'M 23,15 L 23,18'
    ) }
)
foreach ($icon in $icons) {
    $visual = [Windows.Media.DrawingVisual]::new()
    $context = $visual.RenderOpen()
    $context.DrawRectangle([Windows.Media.Brushes]::White, $null, [Windows.Rect]::new(0,0,200,200))
    $context.PushTransform([Windows.Media.ScaleTransform]::new(6.25,6.25))
    $pen = [Windows.Media.Pen]::new([Windows.Media.Brushes]::Black,1.8)
    $pen.StartLineCap = $pen.EndLineCap = [Windows.Media.PenLineCap]::Round
    $pen.LineJoin = [Windows.Media.PenLineJoin]::Round
    foreach ($path in $icon.Paths) {
        $context.DrawGeometry($null,$pen,[Windows.Media.Geometry]::Parse($path))
    }
    $context.Close()
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new(200,200,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $directory = Join-Path $root ($icon.Name + '/' + $icon.Folder + '/Common')
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $file = Join-Path $directory 'Picture.png'
    $stream = [IO.File]::Create($file)
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
    Get-Item -LiteralPath $file | Select-Object FullName,Length
}
