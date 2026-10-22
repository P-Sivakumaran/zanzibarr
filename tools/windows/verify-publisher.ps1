[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string[]]$AllowedThumbprints
)
$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $Path).Path
if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw 'Artifact must be a file.' }
$allowed = @($AllowedThumbprints | ForEach-Object {
    if ($_ -notmatch '^[A-Fa-f0-9]{40}$') { throw 'Expected exact certificate thumbprints.' }
    $_.ToUpperInvariant()
})
$signature = Get-AuthenticodeSignature -LiteralPath $resolved
if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate) {
    throw 'Publisher verification failed: a valid Authenticode signature is required.'
}
if ($signature.SignerCertificate.Thumbprint.ToUpperInvariant() -notin $allowed) {
    throw 'Publisher verification failed: the signing certificate is not trusted.'
}
Write-Output 'Publisher signature and pinned certificate verified.'
