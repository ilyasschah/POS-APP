; -- octopus_setup.iss --
; Inno Setup Script for Octopus POS (Flutter Windows App)

#define AppName "Octopus POS"
#define AppPublisher "FUTUR3"
#define AppExeName "pos_app.exe"
#define BuildDir "build\windows\x64\runner\Release"

; The version comes from OUTSIDE this file, so pubspec.yaml stays the single
; source of truth. The release pipeline reads `version:` from pubspec and passes
; it in:
;     ISCC octopus_setup.iss /DAppVersion=1.2.3
;
; ⚠️ It MUST be plain numeric "major.minor.patch". VersionInfoVersion below
; rejects anything else at compile time, so strip pubspec's "+build" suffix and
; do not pass pre-release tags like "1.2.3-beta".
;
; The fallback exists only so the script still compiles by hand. 0.0.0 is chosen
; because it is obviously not a release — a hardcoded "1.0.0" here is exactly how
; the installer's number stopped matching the app's in the first place.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; General App Information
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
WizardStyle=modern

; ⚠️ Identity for upgrades. Inno keys "is this an upgrade or a second install?"
; on AppId, and when AppId is absent it silently falls back to AppName — so
; renaming the product would turn every future update into a parallel install
; with a duplicate Add/Remove Programs entry.
; The literal string below is the value AppName was already producing, so
; existing installations in the field keep upgrading in place. Do NOT change it
; to a GUID without accepting that those machines need a manual uninstall first.
AppId=Octopus POS

; Stamps the version onto the setup .exe itself, so the file's Properties tab
; agrees with what it installs.
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoCompany={#AppPublisher}

; Default Installation Folder
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}

; Output Settings (Where the setup.exe will be saved)
; Output/ is git-ignored — installers belong on a GitHub Release, not in the repo.
; The filename carries the real version so two builds can never overwrite each
; other, and so a downloaded file says what it is.
OutputDir=Output
OutputBaseFilename=Octopus_POS_Setup_v{#AppVersion}
Compression=lzma2
SolidCompression=yes

; Icons
UninstallDisplayIcon={app}\{#AppExeName}
SetupIconFile=app_icon.ico
AppMutex=OctopusPOSMutex
[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 1. The Main Executable
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; 2. All .dll files in the Release folder
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; 3. The "data" folder (contains Flutter assets, fonts, and core logic)
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; 4. The Visual C++ Redistributable installer
Source: "VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

; 5. THE FIX: Copy the icon file into the install folder so the shortcut can use it
Source: "app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Start Menu Shortcut (Explicitly uses the app_icon.ico)
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\app_icon.ico"
; Desktop Shortcut (Explicitly uses the app_icon.ico)
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
; Silently install Visual C++ Redistributable if the system needs it
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/install /passive /norestart"; Check: VCRedistNeedsInstall; Flags: waituntilterminated

; Launch the app automatically after installation finishes
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

; ── Uninstall deliberately leaves local data behind ──────────────────────────
;
; There is no [UninstallDelete] section, and that is a decision, not an omission.
; The three entries that used to be here were removed because every one of them
; was either wrong or dangerous:
;
;  1. THE PATHS WERE MOSTLY DEAD. Measured on a real install: only
;     {userappdata}\com.example\pos_app exists. {localappdata}\com.example\pos_app
;     and {userdocs}\com.example\pos_app do not exist and never did, so two of the
;     three lines deleted nothing while reading as though they cleaned up.
;
;  2. THE DATABASE WAS NEVER COVERED ANYWAY. Drift opens
;     getApplicationDocumentsDirectory()/pos_app.sqlite — i.e. Documents\pos_app.sqlite,
;     NOT a com.example\pos_app subfolder. The one file that matters was the one
;     file no entry matched.
;
;  3. PER-USER PATHS ARE UNRELIABLE HERE. This installer runs elevated
;     (DefaultDirName is under Program Files), so {userappdata} / {localappdata} /
;     {userdocs} resolve to the profile of whoever ran the uninstaller — typically
;     an admin, not the cashier whose data it was meant to remove. Inno warns about
;     exactly this at compile time ("UsedUserAreasWarning").
;
;  4. IT WOULD DESTROY MONEY. pos_app.sqlite holds sales that have not yet synced
;     to the server. Uninstall-to-reinstall is a routine troubleshooting step, and
;     silently wiping unpushed transactions during one is unacceptable for a POS.
;
; To remove a terminal's data on purpose, delete these by hand while signed in as
; that Windows user — after confirming the Sync panel shows nothing pending:
;     %APPDATA%\com.example\pos_app     (settings, credentials)
;     %USERPROFILE%\Documents\pos_app.sqlite   (the local database)

[Code]
// Pascal Script to check if the Visual C++ Redistributable is already installed
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  // Check the Windows Registry for the VC++ 2015-2022 Redistributable
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
  begin
    // If it exists, we don't need to install it
    Result := False;
  end
  else
  begin
    // If it doesn't exist, tell the installer to run it
    Result := True;
  end;
end;