param(
    [string]$InputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "statua_post\religious+statue+3d+model.obj"),
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "altro\san-catello-post-restauro.stl"),
    [double]$TargetHeightMillimeters = 1075
)

$ErrorActionPreference = "Stop"
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$numberStyle = [System.Globalization.NumberStyles]::Float
$resolvedInput = [System.IO.Path]::GetFullPath($InputPath)
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
$temporaryOutput = $resolvedOutput + ".tmp"

if (-not (Test-Path -LiteralPath $resolvedInput -PathType Leaf)) {
    throw "Sorgente OBJ non trovata: $resolvedInput"
}

if ($TargetHeightMillimeters -le 0) {
    throw "L'altezza finale deve essere maggiore di zero."
}

$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
}

if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Il file di destinazione esiste già: $resolvedOutput"
}

$vertices = [System.Collections.Generic.List[float]]::new(1125000)
$faceIndices = [System.Collections.Generic.List[int]]::new(2250000)
$minimumY = [double]::PositiveInfinity
$maximumY = [double]::NegativeInfinity

$reader = [System.IO.File]::OpenText($resolvedInput)
try {
    while (($line = $reader.ReadLine()) -ne $null) {
        if ($line.StartsWith("v ", [System.StringComparison]::Ordinal)) {
            $parts = $line.Split([char]' ', [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($parts.Length -lt 4) {
                throw "Vertice OBJ non valido: $line"
            }

            $x = [float]::Parse($parts[1], $numberStyle, $culture)
            $y = [float]::Parse($parts[2], $numberStyle, $culture)
            $z = [float]::Parse($parts[3], $numberStyle, $culture)
            $vertices.Add($x)
            $vertices.Add($y)
            $vertices.Add($z)

            if ($y -lt $minimumY) { $minimumY = $y }
            if ($y -gt $maximumY) { $maximumY = $y }
            continue
        }

        if (-not $line.StartsWith("f ", [System.StringComparison]::Ordinal)) {
            continue
        }

        $parts = $line.Split([char]' ', [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($parts.Length -lt 4) {
            throw "Faccia OBJ non valida: $line"
        }

        $polygon = [System.Collections.Generic.List[int]]::new($parts.Length - 1)
        for ($partIndex = 1; $partIndex -lt $parts.Length; $partIndex++) {
            $vertexToken = $parts[$partIndex]
            $slashIndex = $vertexToken.IndexOf('/')
            if ($slashIndex -ge 0) {
                $vertexToken = $vertexToken.Substring(0, $slashIndex)
            }

            $vertexIndex = [int]::Parse($vertexToken, $culture)
            if ($vertexIndex -gt 0) {
                $vertexIndex--
            }
            else {
                $vertexIndex = ($vertices.Count / 3) + $vertexIndex
            }
            $polygon.Add($vertexIndex)
        }

        for ($triangleIndex = 1; $triangleIndex -lt $polygon.Count - 1; $triangleIndex++) {
            $faceIndices.Add($polygon[0])
            $faceIndices.Add($polygon[$triangleIndex])
            $faceIndices.Add($polygon[$triangleIndex + 1])
        }
    }
}
finally {
    $reader.Dispose()
}

$vertexCount = [int]($vertices.Count / 3)
$triangleCount = [int]($faceIndices.Count / 3)
$sourceHeight = $maximumY - $minimumY

if ($vertexCount -eq 0 -or $triangleCount -eq 0 -or $sourceHeight -le 0) {
    throw "La sorgente OBJ non contiene una mesh convertibile."
}

$scale = $TargetHeightMillimeters / $sourceHeight
$minimumX = [double]::PositiveInfinity
$maximumX = [double]::NegativeInfinity
$minimumPrintY = [double]::PositiveInfinity
$maximumPrintY = [double]::NegativeInfinity

for ($vertexIndex = 0; $vertexIndex -lt $vertexCount; $vertexIndex++) {
    $offset = $vertexIndex * 3
    $printX = [double]$vertices[$offset] * $scale
    $printY = -[double]$vertices[$offset + 2] * $scale
    if ($printX -lt $minimumX) { $minimumX = $printX }
    if ($printX -gt $maximumX) { $maximumX = $printX }
    if ($printY -lt $minimumPrintY) { $minimumPrintY = $printY }
    if ($printY -gt $maximumPrintY) { $maximumPrintY = $printY }
}

$stream = [System.IO.File]::Create($temporaryOutput)
$writer = [System.IO.BinaryWriter]::new($stream)
try {
    $headerText = "San Catello post restauro | Z-up | millimetri | altezza 1075 mm"
    $header = [byte[]]::new(80)
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerText)
    [System.Array]::Copy($headerBytes, $header, [Math]::Min($headerBytes.Length, $header.Length))
    $writer.Write($header)
    $writer.Write([uint32]$triangleCount)

    for ($faceOffset = 0; $faceOffset -lt $faceIndices.Count; $faceOffset += 3) {
        $coordinates = [float[]]::new(9)
        for ($corner = 0; $corner -lt 3; $corner++) {
            $vertexIndex = $faceIndices[$faceOffset + $corner]
            if ($vertexIndex -lt 0 -or $vertexIndex -ge $vertexCount) {
                throw "Indice vertice fuori intervallo: $vertexIndex"
            }

            $vertexOffset = $vertexIndex * 3
            $coordinateOffset = $corner * 3
            $coordinates[$coordinateOffset] = [float]([double]$vertices[$vertexOffset] * $scale)
            $coordinates[$coordinateOffset + 1] = [float](-[double]$vertices[$vertexOffset + 2] * $scale)
            $coordinates[$coordinateOffset + 2] = [float](([double]$vertices[$vertexOffset + 1] - $minimumY) * $scale)
        }

        $ux = [double]$coordinates[3] - $coordinates[0]
        $uy = [double]$coordinates[4] - $coordinates[1]
        $uz = [double]$coordinates[5] - $coordinates[2]
        $vx = [double]$coordinates[6] - $coordinates[0]
        $vy = [double]$coordinates[7] - $coordinates[1]
        $vz = [double]$coordinates[8] - $coordinates[2]
        $normalX = ($uy * $vz) - ($uz * $vy)
        $normalY = ($uz * $vx) - ($ux * $vz)
        $normalZ = ($ux * $vy) - ($uy * $vx)
        $normalLength = [Math]::Sqrt(($normalX * $normalX) + ($normalY * $normalY) + ($normalZ * $normalZ))

        if ($normalLength -gt 0) {
            $normalX /= $normalLength
            $normalY /= $normalLength
            $normalZ /= $normalLength
        }
        else {
            $normalX = 0
            $normalY = 0
            $normalZ = 0
        }

        $writer.Write([float]$normalX)
        $writer.Write([float]$normalY)
        $writer.Write([float]$normalZ)
        foreach ($coordinate in $coordinates) {
            $writer.Write([float]$coordinate)
        }
        $writer.Write([uint16]0)

        $completedTriangles = [int](($faceOffset / 3) + 1)
        if (($completedTriangles % 100000) -eq 0) {
            Write-Output ("Triangoli scritti: {0:N0}/{1:N0}" -f $completedTriangles, $triangleCount)
        }
    }
}
finally {
    $writer.Dispose()
    $stream.Dispose()
}

Move-Item -LiteralPath $temporaryOutput -Destination $resolvedOutput

[PSCustomObject]@{
    Output = $resolvedOutput
    Format = "STL binario"
    Vertices = $vertexCount
    Triangles = $triangleCount
    WidthMillimeters = [Math]::Round($maximumX - $minimumX, 2)
    DepthMillimeters = [Math]::Round($maximumPrintY - $minimumPrintY, 2)
    HeightMillimeters = [Math]::Round($TargetHeightMillimeters, 2)
    Bytes = (Get-Item -LiteralPath $resolvedOutput).Length
} | Format-List
