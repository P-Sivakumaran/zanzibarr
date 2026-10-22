[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$UnsignedArtifact)
$ErrorActionPreference='Stop'
$artifact=(Resolve-Path -LiteralPath $UnsignedArtifact).Path
if ((Get-AuthenticodeSignature -LiteralPath $artifact).Status -ne 'NotSigned') {
    throw 'This regression requires an actually unsigned fixture.'
}
$pin='1'*40
$global:zanzibarrPublisherTestFixture=$null
function Get-AuthenticodeSignature {
    param([string]$LiteralPath)
    return $global:zanzibarrPublisherTestFixture
}
try {
    $global:zanzibarrPublisherTestFixture=[pscustomobject]@{Status='Valid';SignerCertificate=[pscustomobject]@{Thumbprint=$pin}}
    & "$PSScriptRoot/verify-publisher.ps1" -Path $artifact -AllowedThumbprints @($pin)
    foreach ($fixture in @(
        [pscustomobject]@{Status='Valid';SignerCertificate=[pscustomobject]@{Thumbprint=('2'*40)}},
        [pscustomobject]@{Status='HashMismatch';SignerCertificate=[pscustomobject]@{Thumbprint=$pin}},
        [pscustomobject]@{Status='NotSigned';SignerCertificate=$null}
    )) {
        $global:zanzibarrPublisherTestFixture=$fixture
        $rejected=$false
        try { & "$PSScriptRoot/verify-publisher.ps1" -Path $artifact -AllowedThumbprints @($pin) } catch { $rejected=$true }
        if (-not $rejected) { throw 'An untrusted signature fixture was accepted.' }
    }
} finally {
    Remove-Item Function:Get-AuthenticodeSignature
    Remove-Variable zanzibarrPublisherTestFixture -Scope Global -ErrorAction SilentlyContinue
}
$rejected=$false
try { & "$PSScriptRoot/verify-publisher.ps1" -Path $artifact -AllowedThumbprints @($pin) } catch { $rejected=$true }
if (-not $rejected) { throw 'An actually unsigned file was accepted.' }
Write-Output 'Publisher verification regressions passed (mock trust decisions and actual unsigned rejection).'
