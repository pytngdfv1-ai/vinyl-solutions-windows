; Instalador de VinylSolutions (Windows). Lo compila el CI con Inno Setup.
; Parámetros: /DAppVersion=X.Y.Z /DSourceDir=<carpeta Release> /DOutputDir=<salida>
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif
#define AppExe "vinyl_solutions.exe"

[Setup]
AppId={{5D08DC42-C050-4E8F-BBF3-1A0CEDBE9E82}
AppName=VinylSolutions
AppVersion={#AppVersion}
AppPublisher=pytngdfv1-ai
DefaultDirName={autopf}\VinylSolutions
DefaultGroupName=VinylSolutions
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=VinylSolutions-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Instalación por usuario: las actualizaciones no piden permisos de administrador.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#AppExe}
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\VinylSolutions"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\VinylSolutions"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; Instalación normal: ofrece abrir la app. Actualización silenciosa: la reabre sola.
Filename: "{app}\{#AppExe}"; Description: "Abrir VinylSolutions"; Flags: nowait postinstall skipifsilent
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: WizardSilent
