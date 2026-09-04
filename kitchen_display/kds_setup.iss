; Octopus Kitchen Display - Inno Setup
;
; Modelled on Front-End\octopus_setup.iss. Kept deliberately simpler in two ways:
;
;   * No uninstall-time data removal. The POS installer offers to delete a local
;     SQLite database because that database IS the till's unsynced sales. The KDS
;     holds only its pairing/config (see lib\kds_storage.dart) — worth keeping
;     across a reinstall, and never worth a scary prompt on a kitchen screen.
;   * No in-app updater to satisfy, so there is no AppMutex handshake with a
;     running instance beyond the standard one below.

#define AppName "Octopus Kitchen Display"
#define AppPublisher "FUTUR3"
#define AppExeName "kitchen_display.exe"
#define BuildDir "build\windows\x64\runner\Release"

; The workflow passes /DAppVersion from pubspec.yaml. The fallback exists only
; so a hand build on a dev machine still produces something, and is deliberately
; an obviously-wrong number rather than a plausible one.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
; Stable AppId is what makes an install an UPGRADE rather than a second copy
; sitting beside the first. Never change it once shipped.
AppId=Octopus Kitchen Display
WizardStyle=modern

VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoCompany={#AppPublisher}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}

OutputDir=Output
OutputBaseFilename=Octopus_KDS_Setup_v{#AppVersion}
Compression=lzma2
SolidCompression=yes

SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
; Blocks an upgrade while the display is running, so Windows is never asked to
; replace a locked .exe. /CLOSEAPPLICATIONS lets a silent install handle it.
AppMutex=OctopusKDSMutex

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
; A kitchen screen is switched on and expected to just show orders. Nobody is
; standing there to click a shortcut, so starting with Windows is offered — and
; unlike the desktop icon it is checked by default.
Name: "startupicon"; Description: "Start automatically when Windows starts"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; Shared with the POS installer rather than committing a second 25 MB copy of
; the same Microsoft redistributable into this repository.
Source: "..\Front-End\VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: startupicon

[Run]
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/install /passive /norestart"; Check: VCRedistNeedsInstall; Flags: waituntilterminated
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// A Flutter Windows build links against the VC++ runtime and fails to start
// without it, with an error that names a DLL rather than the cause.
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  Result :=
    not RegQueryStringValue(
      HKEY_LOCAL_MACHINE,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
      'Version',
      Version
    );
end;
