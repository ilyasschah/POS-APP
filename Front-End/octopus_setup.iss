; Octopus POS - Inno Setup

#define AppName "Octopus POS"
#define AppPublisher "FUTUR3"
#define AppExeName "pos_app.exe"
#define BuildDir "build\windows\x64\runner\Release"

#ifndef AppVersion
  #define AppVersion "1.0.9"
#endif

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppId=Octopus POS
WizardStyle=modern

VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoCompany={#AppPublisher}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}

OutputDir=Output
OutputBaseFilename=Octopus_POS_Setup_v{#AppVersion}
Compression=lzma2
SolidCompression=yes

SetupIconFile=app_icon.ico
UninstallDisplayIcon={app}\app_icon.ico
AppMutex=OctopusPOSMutex

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/install /passive /norestart"; Check: VCRedistNeedsInstall; Flags: waituntilterminated
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
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

  DeleteFile(Docs + '\pos_app.restore.sqlite');
  DeleteFile(Docs + '\pos_app.superseded.sqlite');

  if Failed <> '' then
    MsgBox('Some local data could not be removed - it may still be in use:' + #13#10#13#10 +
         Failed + #13#10 +
         'Close anything using these files and delete them by hand.',
         mbError, MB_OK)
  else
    MsgBox(
      'This terminal''s local data has been removed.' + #13#10#13#10 +
      'Your backup folder was NOT touched.',
      mbInformation,
      MB_OK
    );
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Prompt: String;
begin
  if CurUninstallStep <> usPostUninstall then
    Exit;

  if UninstallSilent then
    Exit;

  if (not DirExists(LocalDataDir)) and (not FileExists(LocalDatabaseFile)) then
    Exit;

  Prompt :=
    'Octopus POS has been uninstalled.' + #13#10#13#10 +
    'Also remove this terminal''s local data?' + #13#10#13#10 +
    'Settings and credentials:' + #13#10 +
    '    ' + LocalDataDir + #13#10 +
    'Local database:' + #13#10 +
    '    ' + LocalDatabaseFile + #13#10#13#10 +
    'Backups are NOT removed.' + #13#10#13#10 +
    'Answer No if you are reinstalling or troubleshooting. The app can reuse ' +
    'this data.' + #13#10#13#10 +
    'Verify that these paths belong to the intended Windows user.';

  if MsgBox(Prompt, mbConfirmation, MB_YESNO or MB_DEFBUTTON2) <> IDYES then
    Exit;

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

    if MsgBox(Prompt, mbError, MB_YESNO or MB_DEFBUTTON2) <> IDYES then
      Exit;
  end;

  RemoveLocalData;
end;
