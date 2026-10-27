; Angels95 installer (NSIS)
;
; Wraps the already-assembled `System/` release folder (client, editor,
; servers, DLLs and the packaged `System/Data/*.oz*` game data) into a single
; self-contained setup .exe. That folder is exactly what the CI "Assemble
; System/ release" + "Package assets" steps produce, and what `System-<tag>.zip`
; contains. Building an installer out of it means a user who downloads ONE file
; gets a playable game instead of a bare client .exe that errors with
; "GameData/ dir is missing".
;
; Compile-time inputs (all set by build-installer.ps1, all SPACE-FREE paths —
; the Angels95 repo forbids spaces/parentheses in paths):
;   VERSION  - release tag / build id, e.g. b117  (default "dev")
;   SRC_DIR  - absolute path to the assembled System/ folder (default "System")
;   OUT_DIR  - absolute path where the setup .exe is written (default ".")
;
; The installer lays files out exactly like a loose `System-<tag>.zip` does:
;   <install root>/
;     System/            (Angels95.exe, AngelEd.exe, servers, DLLs, Data/*.oz*)
;     GameData/Saves/    (pre-created and writable — the client writes saves here)
;
; `$LOCALAPPDATA` is the default root because the client writes its settings
; (System/Angels95.ini) and saves into the install tree at runtime; a per-user
; location is writable without elevation.

Unicode true

!include "MUI2.nsh"

!ifndef VERSION
  !define VERSION "dev"
!endif
!ifndef SRC_DIR
  !define SRC_DIR "System"
!endif
!ifndef OUT_DIR
  !define OUT_DIR "."
!endif

!define PRODUCT_NAME "Angels95"
!define PRODUCT_PUBLISHER "TribeWarez"
!define PRODUCT_WEB_SITE "https://github.com/TribeWarez/Angels-95"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"

Name "${PRODUCT_NAME} ${VERSION}"
OutFile "${OUT_DIR}\Angels95-Setup-${VERSION}.exe"
InstallDir "$LOCALAPPDATA\${PRODUCT_NAME}"
InstallDirRegKey HKCU "${PRODUCT_UNINST_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!define MUI_ICON "angels95.ico"
!define MUI_UNICON "angels95.ico"
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ---- payload ------------------------------------------------------------
Section "Angels95 (client + editor + servers)" SecMain
  SectionIn RO
  ; Everything in System/ (exes, DLLs, INI templates, run scripts, systemd
  ; units, and the packaged System/Data/*.oz* game data).
  SetOutPath "$INSTDIR\System"
  File /r "${SRC_DIR}\*.*"

  ; The client writes settings to System/Angels95.ini and saves to
  ; GameData/Saves/* relative to the install root. Pre-create the saves folder
  ; so a fresh install persists progress without an empty-open failure.
  SetOutPath "$INSTDIR\GameData\Saves"
  CreateDirectory "$INSTDIR\GameData\Saves"
  SetOutPath "$INSTDIR"
SectionEnd

Section "Start Menu shortcuts" SecStartMenu
  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  ; SetOutPath sets the shortcut's working directory ("Start in"). The client
  ; also re-derives the root itself (RelocateToInstallRoot), so this is belt
  ; and braces rather than load-bearing.
  SetOutPath "$INSTDIR"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Angels95.lnk" \
    "$INSTDIR\System\Angels95.exe" "" "$INSTDIR\System\Angels95.exe" 0
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\AngelEd (Level Editor).lnk" \
    "$INSTDIR\System\AngelEd.exe" "" "$INSTDIR\System\AngelEd.exe" 0
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall Angels95.lnk" \
    "$INSTDIR\Uninstall.exe"
SectionEnd

Section /o "Desktop shortcut" SecDesktop
  SetOutPath "$INSTDIR"
  CreateShortCut "$DESKTOP\Angels95.lnk" \
    "$INSTDIR\System\Angels95.exe" "" "$INSTDIR\System\Angels95.exe" 0
SectionEnd

; ---- uninstaller metadata -----------------------------------------------
Section -Post
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "DisplayName" "${PRODUCT_NAME} ${VERSION}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\System\Angels95.exe"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegDWORD HKCU "${PRODUCT_UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${PRODUCT_UNINST_KEY}" "NoRepair" 1
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} "The game, the AngelEd level editor and the AngelServ/AngelMaster servers, with all packaged game data."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartMenu} "Start Menu shortcuts for the game and the level editor."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "A desktop shortcut for the game."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ---- uninstall ----------------------------------------------------------
Section "Uninstall"
  Delete "$INSTDIR\Uninstall.exe"

  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Angels95.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\AngelEd (Level Editor).lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall Angels95.lnk"
  RMDir "$SMPROGRAMS\${PRODUCT_NAME}"
  Delete "$DESKTOP\Angels95.lnk"

  ; Remove the game files. Saves (GameData/Saves) are left in place on purpose
  ; so an uninstall/reinstall keeps player progress; the folders are removed
  ; only when empty (RMDir without /r does not recurse).
  RMDir /r "$INSTDIR\System"
  RMDir "$INSTDIR\GameData\Saves"
  RMDir "$INSTDIR\GameData"
  RMDir "$INSTDIR"

  DeleteRegKey HKCU "${PRODUCT_UNINST_KEY}"
SectionEnd
