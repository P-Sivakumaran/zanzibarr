#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef BundleDir
  #error BundleDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif

[Setup]
AppId={{C39B6F7D-9326-4E4B-B0AE-123BCB782461}
AppName=zanzibarr
AppVersion={#AppVersion}
AppPublisher=zanzibarr contributors
DefaultDirName={localappdata}\Programs\zanzibarr
DefaultGroupName=zanzibarr
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir={#OutputDir}
OutputBaseFilename=zanzibarr-windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\zanzibarr.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes

[Tasks]
Name: desktopicon; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\zanzibarr"; Filename: "{app}\zanzibarr.exe"
Name: "{autodesktop}\zanzibarr"; Filename: "{app}\zanzibarr.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\zanzibarr.exe"; Description: "Launch zanzibarr"; Flags: nowait postinstall skipifsilent
