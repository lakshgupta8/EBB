; The installer for EBB. Build it with tools\installer.ps1, which exports the game,
; stamps the version in and calls ISCC on this file.
;
; What it puts on the machine, and what the uninstaller therefore takes off again:
;   {app}\EBB.exe            the whole game (the pack is inside the exe)
;   {app}\unins000.exe       the uninstaller, next to the game, as asked for
;   Desktop\EBB.lnk          optional, ticked by default
;   Start Menu\EBB\          the game and its uninstaller
;   Uninstall registry key   so it shows up in Apps & features
; Saves are not the installer's doing, so it leaves them alone unless you say otherwise
; at uninstall time; see CurUninstallStepChanged below.

#define AppName "EBB"
#define AppExe "EBB.exe"
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Never change AppId: it is how a later installer recognises an older EBB and updates it
; in place instead of installing a second copy.
AppId={{1E6307C6-7D96-4CDE-B1CC-0405071EF26E}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Lakshya Gupta
VersionInfoVersion={#AppVersion}
VersionInfoDescription={#AppName} setup
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
; An update keeps the folder the last install chose, and skips the folder page.
UsePreviousAppDir=yes
DisableDirPage=auto
DisableProgramGroupPage=yes
AllowNoIcons=yes
; No admin needed: {autopf} then means %LOCALAPPDATA%\Programs. The folder page still
; lets you put the game on whichever drive you like.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
SetupIconFile=ebb.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName} {#AppVersion}
OutputDir=..\dist
OutputBaseFilename={#AppName}-Setup-{#AppVersion}
; Updating over a running game: offer to close it rather than fail on the locked exe.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\dist\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
// Keepers, settings and replays live outside the install folder, in Godot's user data.
// The installer never wrote them, so the uninstaller asks before taking them: a silent
// uninstall (and anyone who just hits Enter) keeps them.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Data: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    Data := ExpandConstant('{userappdata}\Godot\app_userdata\{#AppName}');
    if DirExists(Data) then
      if SuppressibleMsgBox('Also delete your keepers, settings and replays?' + #13#10 + #13#10 +
        Data, mbConfirmation, MB_YESNO or MB_DEFBUTTON2, IDNO) = IDYES then
        DelTree(Data, True, True, True);
  end;
end;
