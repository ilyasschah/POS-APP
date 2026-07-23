; -- octopus_setup.iss --
; Inno Setup Script for Octopus POS (Flutter Windows App)

#define AppName "Octopus POS"
#define AppVersion "1.0.0"
#define AppPublisher "FUTUR3"
#define AppExeName "pos_app.exe"
#define BuildDir "build\windows\x64\runner\Release"

[Setup]
; General App Information
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
WizardStyle=modern

; Default Installation Folder
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}

; Output Settings (Where the setup.exe will be saved)
OutputDir=Output
OutputBaseFilename=Octopus_POS_Setup_v1.0
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

[UninstallDelete]
; Wipes the Roaming AppData folder (where shared_preferences.json and secure storage live)
Type: filesandordirs; Name: "{userappdata}\com.example\pos_app"
; Wipes the Local AppData folder (where some caches or DBs might live)
Type: filesandordirs; Name: "{localappdata}\com.example\pos_app"
; Wipes the Documents folder (just in case Drift DBs were saved here)
Type: filesandordirs; Name: "{userdocs}\com.example\pos_app"

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