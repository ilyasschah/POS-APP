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
  #define AppVersion "1.0.9"
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

; ── Uninstall keeps local data unless the operator explicitly opts in ────────
;
; There is still NO [UninstallDelete] section. The removal lives in [Code]
; (CurUninstallStepChanged), opt-in and interactive, because every declarative
; version of it was either wrong or dangerous:
;
;  1. THE PATHS WERE MOSTLY DEAD. Measured on a real install: only
;     {userappdata}\com.example\pos_app exists. {localappdata}\com.example\pos_app
;     and {userdocs}\com.example\pos_app do not exist and never did, so two of the
;     three lines deleted nothing while reading as though they cleaned up.
;
;  2. THE DATABASE WAS NEVER COVERED ANYWAY. Drift opens
;     getApplicationDocumentsDirectory()/pos_app.sqlite — i.e. Documents\pos_app.sqlite,
;     NOT a com.example\pos_app subfolder. The one file that matters was the one
;     file no entry matched. {userdocs} is what resolves it, and it follows a
;     redirected Documents folder (OneDrive), which is where it actually sits on
;     the machines in the field.
;
;  3. PER-USER PATHS ARE UNRELIABLE HERE. This installer runs elevated
;     (DefaultDirName is under Program Files), so {userappdata} / {localappdata} /
;     {userdocs} resolve to the profile of whoever ran the uninstaller — typically
;     an admin, not the cashier whose data it was meant to remove. Unsolvable in a
;     declarative section; handled below by PRINTING the resolved paths in the
;     prompt, so a wrong profile is visible before anything is deleted.
;
;  4. IT WOULD DESTROY MONEY. pos_app.sqlite holds sales that have not yet synced
;     to the server. Uninstall-to-reinstall is a routine troubleshooting step, and
;     silently wiping unpushed transactions during one is unacceptable for a POS.
;     Hence: two prompts, both defaulting to No, the second naming the file.
;
; What the opt-in step removes:
;     %APPDATA%\com.example\pos_app          settings + credentials (secure storage)
;     {userdocs}\pos_app.sqlite              the local database
;     {userdocs}\pos_app.restore.sqlite      restore staging leftovers
;     {userdocs}\pos_app.superseded.sqlite   (see lib/database/restore_service.dart)
;
; What it NEVER removes: the backup folder (POS_Backups). Backups are the only
; way back from this action — deleting them alongside the data would turn a
; recoverable mistake into a permanent one.
;
; Skipped entirely on a silent uninstall: data is never deleted without a human
; reading the prompt.
;
; To do it by hand instead, while signed in as that Windows user and after the
; Sync panel shows nothing pending, delete the four paths listed above.

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

// ── Optional removal of this terminal's local data (uninstall only) ──────────
// Opt-in, interactive, default No. See the rationale above [Code].

function LocalDataDir: String;
begin
  Result := ExpandConstant('{userappdata}\com.example\pos_app');
end;

function LocalDatabaseFile: String;
begin
  Result := ExpandConstant('{userdocs}\pos_app.sqlite');
end;

procedure RemoveLocalData;
var
  Docs: String;
  Failed: String;
begin
  Docs := ExpandConstant('{userdocs}');
  Failed := '';

  if DirExists(LocalDataDir) then
    if not DelTree(LocalDataDir, True, True, True) then
      Failed := Failed + '    ' + LocalDataDir + #13#10;

  if FileExists(LocalDatabaseFile) then
    if not DeleteFile(LocalDatabaseFile) then
      Failed := Failed + '    ' + LocalDatabaseFile + #13#10;

  // Restore leftovers share the database's folder and lifecycle. Absent on a
  // terminal that never restored, so their removal is not reported.
  DeleteFile(Docs + '\pos_app.restore.sqlite');
  DeleteFile(Docs + '\pos_app.superseded.sqlite');

  if Failed <> '' then
  MsgBox('Some local data could not be removed - it may still be in use:' + #13#10#13#10 +
         Failed + #13#10 +
         'Close anything using these files and delete them by hand.',
         mbError, MB_OK)
  else
  MsgBox('This terminal''s local data has been removed.' + #13#10#13#10 +
         'Your backup folder was NOT touched.', mbInformation, MB_OK);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Prompt: String;
begin
  if CurUninstallStep <> usPostUninstall then Exit;
  // Never delete data without someone reading the prompt.
  if UninstallSilent then Exit;
  // Nothing of ours in this profile - stay quiet rather than ask about files
  // that do not exist (which is also the signal that the wrong user is running
  // the uninstaller).
  if (not DirExists(LocalDataDir)) and (not FileExists(LocalDatabaseFile)) then Exit;

  Prompt :=
    'Octopus POS has been uninstalled.' + #13#10#13#10 +
    'Also remove this terminal''s local data?' + #13#10#13#10 +
    'Settings and credentials:' + #13#10 +
    '    ' + LocalDataDir + #13#10 +
    'Local database:' + #13#10 +
    '    ' + LocalDatabaseFile + #13#10#13#10 +
    'Backups are NOT removed.' + #13#10#13#10 +
    'Answer No if you are reinstalling or troubleshooting - the app picks this ' +
    'data back up and nothing is lost.' + #13#10#13#10 +
    'Check the paths above name the right Windows user: they belong to the ' +
    'account running this uninstaller, which may not be the cashier''s.';

  if MsgBox(Prompt, mbConfirmation, MB_YESNO or MB_DEFBUTTON2) <> IDYES then Exit;

  if FileExists(LocalDatabaseFile) then
  begin
    Prompt :=
  'LAST CHECK' + #13#10#13#10 +
  LocalDatabaseFile + #13#10#13#10 +
  'This file holds every sale made on this terminal, INCLUDING any that ' +
  'have not reached the cloud yet. Once deleted, only a backup can bring ' +
  'them back.' + #13#10#13#10 +
  'If you are not certain the Sync panel showed 0 pending, answer No.' + #13#10#13#10 +
  'Answering No leaves ALL local data in place.' + #13#10#13#10 +
  'Delete it now?';
    if MsgBox(Prompt, mbError, MB_YESNO or MB_DEFBUTTON2) <> IDYES then Exit;
  end;

  RemoveLocalData;
end;