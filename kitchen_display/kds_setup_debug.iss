; Octopus Kitchen Display (DEBUG) - Inno Setup

#define AppName "Octopus Kitchen Display Debug"
#define AppPublisher "FUTUR3"
#define AppExeName "kitchen_display.exe"
#define BuildDir "build\windows\x64\runner\Debug"

#ifndef AppVersion
  #define AppVersion "1.0.14"
#endif

#ifndef DebugCrtDir
  #define DebugCrtDir GetEnv("ProgramFiles") + "\Microsoft Visual Studio\18\Community\VC\Redist\MSVC\14.51.36231\debug_nonredist\x64\Microsoft.VC145.DebugCRT"
#endif
#ifndef UcrtDebugDir
  #define UcrtDebugDir GetEnv("ProgramFiles(x86)") + "\Windows Kits\10\bin\10.0.26100.0\x64\ucrt"
#endif

#ifndef SkipDebugCrt
  #if !FileExists(DebugCrtDir + "\msvcp140d.dll")
    #pragma error "Debug CRT not found at " + DebugCrtDir + " - pass /DDebugCrtDir=... or /DSkipDebugCrt"
  #endif
  #if !FileExists(UcrtDebugDir + "\ucrtbased.dll")
    #pragma error "ucrtbased.dll not found at " + UcrtDebugDir + " - pass /DUcrtDebugDir=... or /DSkipDebugCrt"
  #endif
#endif

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppId=Octopus Kitchen Display Debug
UninstallDisplayName={#AppName} {#AppVersion}
WizardStyle=modern

VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoCompany={#AppPublisher}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}

OutputDir=Output
OutputBaseFilename=Octopus_KDS_Debug_Setup_v{#AppVersion}
Compression=lzma2/fast
SolidCompression=yes

SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
AppMutex=OctopusKDSMutex

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Start automatically when Windows starts"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

Source: "{#BuildDir}\kitchen_display.pdb"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

Source: "..\Front-End\VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
#ifndef SkipDebugCrt
Source: "{#DebugCrtDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#UcrtDebugDir}\ucrtbased.dll"; DestDir: "{app}"; Flags: ignoreversion
#endif

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: startupicon

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
