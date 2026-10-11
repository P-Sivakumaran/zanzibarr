param([string]$Installer = 'dist/windows/zanzibarr-windows-x64-setup.exe')
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Push-Location $repo
try {
    $installedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{C39B6F7D-9326-4E4B-B0AE-123BCB782461}_is1'
    if (Test-Path -LiteralPath $installedKey) { throw 'An installed copy exists; use a fresh user/VM for the smoke test' }
    $installerPath = (Resolve-Path -LiteralPath $Installer).Path
    $scratch = Join-Path $repo ('dist/windows/installer-smoke-' + [guid]::NewGuid().ToString('N'))
    $scratch = [IO.Path]::GetFullPath($scratch)
    $allowed = [IO.Path]::GetFullPath((Join-Path $repo 'dist/windows')) + [IO.Path]::DirectorySeparatorChar
    if (!$scratch.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Smoke target escaped dist/windows' }
    $log = Join-Path $repo 'dist/windows/installer-smoke.log'
    foreach ($pass in 1..2) {
        $setup = Start-Process -FilePath $installerPath -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/NOICONS', "/DIR=`"$scratch`"", "/LOG=`"$log`"") -WindowStyle Hidden -Wait -PassThru
        if ($setup.ExitCode -ne 0) { throw "Install pass $pass failed: $($setup.ExitCode)" }
        foreach ($file in @('zanzibarr.exe', 'rust_lib_zanzibarr.dll', 'flutter_windows.dll', 'msvcp140.dll', 'vcruntime140.dll', 'data/flutter_assets')) {
            if (!(Test-Path -LiteralPath (Join-Path $scratch $file))) { throw "Installed bundle missing $file" }
        }
        Write-Output "Install pass $pass succeeded"
    }
    $app = Start-Process -FilePath (Join-Path $scratch 'zanzibarr.exe') -WorkingDirectory $scratch -WindowStyle Hidden -PassThru
    try {
        if (!$app.WaitForInputIdle(20000)) { throw 'Application did not become responsive' }
        Start-Sleep -Seconds 3
        $app.Refresh()
        if ($app.HasExited -or !$app.Responding) { throw 'Application exited or stopped responding' }
        Write-Output "Installed application launched and responded; PID $($app.Id)"
    } finally {
        if (!$app.HasExited) {
            # Hidden windows do not have a .NET MainWindowHandle. Terminate
            # only the process created by this test after its responsiveness check.
            Stop-Process -Id $app.Id -Force
            if (!$app.WaitForExit(10000)) { throw 'Smoke-test process did not stop' }
        }
    }
    $uninstall = Start-Process -FilePath (Join-Path $scratch 'unins000.exe') -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -WindowStyle Hidden -Wait -PassThru
    if ($uninstall.ExitCode -ne 0) { throw "Uninstall failed: $($uninstall.ExitCode)" }
    if (Test-Path -LiteralPath (Join-Path $scratch 'zanzibarr.exe')) { throw 'Uninstaller left the executable behind' }
    if (Test-Path -LiteralPath $installedKey) { throw 'Uninstaller left registration behind' }
    Write-Output 'Installer lifecycle smoke passed (install, reinstall, hidden launch, uninstall); rendered UI/playback not assessed'
} finally { Pop-Location }
