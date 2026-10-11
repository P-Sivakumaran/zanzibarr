param([string]$Destination = (Join-Path $env:TEMP 'zanzibarr-inno-6.7.3'))
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$download = Join-Path $Destination 'innosetup-6.7.3.exe'
Invoke-WebRequest -Uri 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe' -OutFile $download
$signature = Get-AuthenticodeSignature -LiteralPath $download
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Pyrsys B\.V\.') {
    throw 'Inno Setup download signature or publisher did not match'
}
$compilerDir = Join-Path $Destination 'compiler'
$process = Start-Process -FilePath $download -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/CURRENTUSER', "/DIR=`"$compilerDir`"") -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Inno Setup install failed: $($process.ExitCode)" }
$compiler = Join-Path $compilerDir 'ISCC.exe'
if (!(Test-Path -LiteralPath $compiler)) { throw 'Inno Setup compiler was not installed' }
Write-Output $compiler
