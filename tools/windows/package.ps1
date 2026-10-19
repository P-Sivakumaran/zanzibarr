param(
    [string]$Iscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    [string]$BundleDir = 'build/windows/x64/runner/Release',
    [string]$OutputDir = 'dist/windows'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Push-Location $repo
try {
    $bundle = (Resolve-Path -LiteralPath $BundleDir).Path
    foreach ($file in @('zanzibarr.exe', 'flutter_windows.dll', 'rust_lib_zanzibarr.dll', 'data/flutter_assets')) {
        if (!(Test-Path -LiteralPath (Join-Path $bundle $file))) { throw "Missing release component: $file" }
    }
    # App-local CRT keeps portable and per-user installs usable on clean PCs.
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$vs) { throw 'Visual Studio C++ tools not found' }
    $redist = Get-ChildItem -LiteralPath (Join-Path $vs 'VC/Redist/MSVC') -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if (!$redist) { throw 'Visual C++ redistributable directory not found' }
    $crt = Join-Path $redist.FullName 'x64/Microsoft.VC143.CRT'
    if (!(Test-Path -LiteralPath $crt)) { throw 'x64 release CRT not found' }
    Copy-Item -Path (Join-Path $crt '*.dll') -Destination $bundle -Force
    foreach ($file in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
        if (!(Test-Path -LiteralPath (Join-Path $bundle $file))) { throw "Missing CRT: $file" }
    }
    $versionLine = Select-String -LiteralPath 'pubspec.yaml' -Pattern '^version: (\d+\.\d+\.\d+)\+(\d+)$'
    if (!$versionLine) { throw 'Expected pubspec version: major.minor.patch+build' }
    $version = $versionLine.Matches[0].Groups[1].Value
    $binaryVersion = (Get-Item -LiteralPath (Join-Path $bundle 'zanzibarr.exe')).VersionInfo.ProductVersion
    if ($binaryVersion -ne "$version+$($versionLine.Matches[0].Groups[2].Value)") {
        throw 'Executable version differs from pubspec; rebuild the release first'
    }
    $integrations = Join-Path $bundle 'integrations'
    New-Item -ItemType Directory -Path $integrations -Force | Out-Null
    Copy-Item -LiteralPath 'tools/zanzibarr_mcp_bridge.py' -Destination $integrations -Force
    $guides = Join-Path $bundle 'docs'
    New-Item -ItemType Directory -Path $guides -Force | Out-Null
    Copy-Item -LiteralPath 'docs/AI_CONNECTIONS.md', 'docs/FILM_CHAT.md', 'docs/INTEGRATIONS.md' -Destination $guides -Force
    $licenses = Join-Path $bundle 'licenses'
    New-Item -ItemType Directory -Path $licenses -Force | Out-Null
    Copy-Item -LiteralPath 'assets/fonts/LeagueMono-OFL.txt' -Destination $licenses -Force
    Copy-Item -LiteralPath 'assets/branding/README.md' -Destination (Join-Path $licenses 'TMDB-attribution.md') -Force
    Get-ChildItem -LiteralPath 'assets/licenses' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $licenses -Force }
    Copy-Item -LiteralPath 'vendor/unrar-sys/vendor/unrar/license.txt' -Destination (Join-Path $licenses 'unrar-license.txt') -Force
    Copy-Item -LiteralPath 'vendor/unrar-rs/LICENSE-MIT' -Destination (Join-Path $licenses 'unrar-rs-MIT.txt') -Force
    Copy-Item -LiteralPath 'vendor/unrar-rs/LICENSE-APACHE' -Destination (Join-Path $licenses 'unrar-rs-APACHE.txt') -Force
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $output = (Resolve-Path -LiteralPath $OutputDir).Path
    if (!(Test-Path -LiteralPath $Iscc)) { throw 'Install Inno Setup 6 or pass -Iscc' }
    & $Iscc "/DAppVersion=$version" "/DBundleDir=$bundle" "/DOutputDir=$output" 'tools/windows/installer.iss'
    if ($LASTEXITCODE -ne 0) { throw "Installer compilation failed: $LASTEXITCODE" }
    Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath (Join-Path $output 'zanzibarr-windows-x64.zip') -Force
    Get-ChildItem -LiteralPath $output -File | Where-Object { $_.Name -match '^zanzibarr-windows-x64(\.zip|-setup\.exe)$' } |
        ForEach-Object { '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name } |
        Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS') -Encoding ascii
} finally { Pop-Location }
