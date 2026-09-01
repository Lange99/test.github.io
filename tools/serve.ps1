param(
    [int]$Port = 4173,
    [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()

Write-Output "Server pronto su http://127.0.0.1:$Port/"

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css" = "text/css; charset=utf-8"
    ".js" = "text/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".glb" = "model/gltf-binary"
    ".gltf" = "model/gltf+json"
    ".usdz" = "model/vnd.usdz+zip"
    ".jpg" = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png" = "image/png"
    ".webp" = "image/webp"
    ".svg" = "image/svg+xml"
}

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
        $requestLine = $reader.ReadLine()

        if ([string]::IsNullOrWhiteSpace($requestLine)) {
            $client.Close()
            continue
        }

        $requestParts = $requestLine.Split(" ")
        $requestMethod = $requestParts[0]
        $requestUrl = [Uri]("http://127.0.0.1" + $requestParts[1])

        do {
            $headerLine = $reader.ReadLine()
        } while (-not [string]::IsNullOrEmpty($headerLine))

        $requestPath = [Uri]::UnescapeDataString($requestUrl.AbsolutePath.TrimStart("/"))

        if ([string]::IsNullOrWhiteSpace($requestPath)) {
            $requestPath = "index.html"
        }

        $filePath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $requestPath.Replace("/", [System.IO.Path]::DirectorySeparatorChar)))

        if (-not $filePath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            $notFound = [Text.Encoding]::UTF8.GetBytes("File non trovato")
            $header = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 404 Not Found`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($notFound.Length)`r`nConnection: close`r`n`r`n")
            $stream.Write($header, 0, $header.Length)
            $stream.Write($notFound, 0, $notFound.Length)
            $stream.Dispose()
            $client.Close()
            continue
        }

        $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
        $contentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { "application/octet-stream" }
        $fileInfo = Get-Item -LiteralPath $filePath
        $headerText = "HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nContent-Length: $($fileInfo.Length)`r`nCache-Control: no-store`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`n`r`n"
        $header = [Text.Encoding]::ASCII.GetBytes($headerText)
        $stream.Write($header, 0, $header.Length)

        if ($requestMethod -ne "HEAD") {
            $fileStream = [System.IO.File]::OpenRead($filePath)
            try {
                $fileStream.CopyTo($stream)
            }
            finally {
                $fileStream.Dispose()
            }
        }

        $stream.Dispose()
        $client.Close()
    }
}
finally {
    $listener.Stop()
}
