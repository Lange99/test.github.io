param(
    [string]$SourceGlb = "statua.glb",
    [string]$BaseColorTexture = "statua/antique+bishop+statue+3d+model_basecolor.jpg",
    [string]$NormalTexture = "statua/antique+bishop+statue+3d+model_normal.jpg",
    [string]$OutputGlb = "statua-colori.glb",
    [switch]$NoNormalMap
)

$ErrorActionPreference = "Stop"

function Align-Four([System.IO.MemoryStream]$Stream, [byte]$PaddingByte = 0) {
    while (($Stream.Length % 4) -ne 0) {
        $Stream.WriteByte($PaddingByte)
    }
}

function Read-Glb([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Path))

    if ([Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne "glTF") {
        throw "Il file sorgente non e un GLB valido."
    }

    if ([BitConverter]::ToUInt32($bytes, 4) -ne 2) {
        throw "E supportato solo glTF 2.0."
    }

    $offset = 12
    $jsonText = $null
    $binary = $null

    while ($offset -lt $bytes.Length) {
        $chunkLength = [BitConverter]::ToUInt32($bytes, $offset)
        $chunkType = [BitConverter]::ToUInt32($bytes, $offset + 4)
        $chunkStart = $offset + 8

        if ($chunkType -eq 0x4E4F534A) {
            $jsonText = [Text.Encoding]::UTF8.GetString($bytes, $chunkStart, $chunkLength).Trim([char]0x20, [char]0)
        }
        elseif ($chunkType -eq 0x004E4942) {
            $binary = New-Object byte[] $chunkLength
            [Array]::Copy($bytes, $chunkStart, $binary, 0, $chunkLength)
        }

        $offset = $chunkStart + $chunkLength
    }

    if (-not $jsonText -or -not $binary) {
        throw "Nel GLB mancano il blocco JSON o il blocco binario."
    }

    return [pscustomobject]@{
        Json = $jsonText | ConvertFrom-Json
        Binary = $binary
    }
}

function Add-EmbeddedImage(
    [System.IO.MemoryStream]$BinaryStream,
    [System.Collections.ArrayList]$BufferViews,
    [string]$Path,
    [string]$Name
) {
    Align-Four $BinaryStream
    $imageBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Path))
    $byteOffset = [int]$BinaryStream.Position
    $BinaryStream.Write($imageBytes, 0, $imageBytes.Length)

    [void]$BufferViews.Add([pscustomobject]@{
        buffer = 0
        byteOffset = $byteOffset
        byteLength = $imageBytes.Length
        name = $Name
    })

    return ($BufferViews.Count - 1)
}

$source = Read-Glb $SourceGlb
$gltf = $source.Json

if (-not $gltf.meshes -or -not $gltf.materials -or -not $gltf.buffers) {
    throw "Il GLB sorgente non contiene mesh, materiale o buffer."
}

$binaryStream = New-Object System.IO.MemoryStream
$binaryStream.Write($source.Binary, 0, $source.Binary.Length)
$binaryStream.Position = $binaryStream.Length

$bufferViews = New-Object System.Collections.ArrayList
foreach ($view in $gltf.bufferViews) {
    [void]$bufferViews.Add($view)
}

$baseColorView = Add-EmbeddedImage $binaryStream $bufferViews $BaseColorTexture "Texture colore"
$normalView = $null
if (-not $NoNormalMap) {
    $normalView = Add-EmbeddedImage $binaryStream $bufferViews $NormalTexture "Texture normali"
}
Align-Four $binaryStream

$gltf.bufferViews = @($bufferViews)
$gltf.buffers[0].byteLength = [int]$binaryStream.Length
$gltf.asset.generator = "San Catello AR asset builder"

$gltf | Add-Member -NotePropertyName samplers -NotePropertyValue @(
    [pscustomobject]@{
        magFilter = 9729
        minFilter = 9987
        wrapS = 10497
        wrapT = 10497
    }
) -Force

$images = @(
    [pscustomobject]@{ name = "Colore originale"; bufferView = $baseColorView; mimeType = "image/jpeg" }
)
$textures = @(
    [pscustomobject]@{ name = "Colore originale"; sampler = 0; source = 0 }
)

if (-not $NoNormalMap) {
    $images += [pscustomobject]@{ name = "Dettaglio superficie"; bufferView = $normalView; mimeType = "image/jpeg" }
    $textures += [pscustomobject]@{ name = "Dettaglio superficie"; sampler = 0; source = 1 }
}

$gltf | Add-Member -NotePropertyName images -NotePropertyValue $images -Force
$gltf | Add-Member -NotePropertyName textures -NotePropertyValue $textures -Force

$material = $gltf.materials[0]
$material.name = "Statua policroma"
$material.pbrMetallicRoughness.baseColorFactor = @(1.0, 1.0, 1.0, 1.0)
$material.pbrMetallicRoughness.metallicFactor = 0.0
$material.pbrMetallicRoughness.roughnessFactor = 0.82
$material.pbrMetallicRoughness | Add-Member -NotePropertyName baseColorTexture -NotePropertyValue ([pscustomobject]@{ index = 0 }) -Force
if ($NoNormalMap) {
    $material.PSObject.Properties.Remove("normalTexture")
}
else {
    $material | Add-Member -NotePropertyName normalTexture -NotePropertyValue ([pscustomobject]@{ index = 1; scale = 0.85 }) -Force
}
$material.doubleSided = $true

$utf8 = New-Object System.Text.UTF8Encoding($false)
$jsonBytes = $utf8.GetBytes(($gltf | ConvertTo-Json -Depth 100 -Compress))
$jsonStream = New-Object System.IO.MemoryStream
$jsonStream.Write($jsonBytes, 0, $jsonBytes.Length)
Align-Four $jsonStream 0x20

$binaryBytes = $binaryStream.ToArray()
$jsonChunk = $jsonStream.ToArray()
$totalLength = 12 + 8 + $jsonChunk.Length + 8 + $binaryBytes.Length

$outputPath = Join-Path (Get-Location) $OutputGlb
$fileStream = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
$writer = New-Object System.IO.BinaryWriter($fileStream)

try {
    $writer.Write([Text.Encoding]::ASCII.GetBytes("glTF"))
    $writer.Write([uint32]2)
    $writer.Write([uint32]$totalLength)
    $writer.Write([uint32]$jsonChunk.Length)
    $writer.Write([uint32]0x4E4F534A)
    $writer.Write($jsonChunk)
    $writer.Write([uint32]$binaryBytes.Length)
    $writer.Write([uint32]0x004E4942)
    $writer.Write($binaryBytes)
}
finally {
    $writer.Dispose()
    $fileStream.Dispose()
    $jsonStream.Dispose()
    $binaryStream.Dispose()
}

$detailMessage = if ($NoNormalMap) { "solo con il colore incorporato" } else { "con colore e normal map incorporati" }
Write-Output "Creato $OutputGlb ($totalLength byte) $detailMessage."
