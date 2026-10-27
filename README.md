# Angels95 Setup

The NSIS installer for [Angels95](https://github.com/TribeWarez/Angels-95). This
repository is meant to be checked out as the **`setup/` submodule** of the main
repo; it wraps the CI-assembled `System/` release folder into one self-contained
`Angels95-Setup-<tag>.exe`.

## Why

The GitHub release publishes a **bare client** (`Angels95-<tag>-windows-x86_64.exe`)
and a **full bundle** (`System-<tag>.zip`). The bare client carries no game data,
so downloading it and running it fails with `GameData/ dir is missing`. A single
installer that bundles `System/` (exes + DLLs + the packaged `System/Data/*.oz*`
data) is the artifact a non-developer should download and run.

## Layout

The installer installs exactly what `System-<tag>.zip` contains, plus a
pre-created writable saves folder:

```
<install root>/            (default: %LOCALAPPDATA%\Angels95)
  System/                  Angels95.exe, AngelEd.exe, AngelServ.exe, AngelMaster.exe,
                           OzPack.exe, raylib/GLFW DLLs, INI templates, run scripts,
                           and System/Data/*.oz* (the packaged game data)
  GameData/Saves/          created empty so the client can persist progress
```

The client self-relocates to the install root via `RelocateToInstallRoot()`
(`Source/Main.cpp`), so the Start Menu / Desktop shortcuts point straight at
`System\Angels95.exe` and the game finds its data regardless of the working
directory.

## Building

Prerequisites:

- An assembled `System/` folder at the **repo root** (the output of the main
  repo's Windows build + `build-data.ps1`, or a decompressed `System-<tag>.zip`
  whose contents are placed under `System/`).
- [NSIS](https://nsis.sourceforge.io/) (`makensis` on PATH, or
  `choco install nsis -y`).

```powershell
# from the main repo root (setup/ is this submodule)
powershell -File setup\build-installer.ps1 -Version b117
# -> release\Angels95-Setup-b117.exe
```

`-Version` defaults to `$env:BUILD_VERSION`, then `dev`. `-OutDir` defaults to
`release\`.

## Notes

- Paths are **space-free** (the Angels95 repo forbids spaces/parentheses in
  paths), so the `/D` defines are passed without quoting.
- Uninstalling removes the game files but **keeps** `GameData/Saves/` so player
  progress survives a reinstall.
- `RequestExecutionLevel user` + `$LOCALAPPDATA` default means no admin prompt
  is needed; the client writes `System/Angels95.ini` and saves at runtime, so a
  per-user writable location is the correct default.

## Publishing to SourceForge

The maintainer uploads `release\Angels95-Setup-<tag>.exe` to the
[Angels 95 SourceForge project](https://sourceforge.net/projects/angels-95/) and
sets it (or the full `System-<tag>.zip`) as the **default download**, so
`https://sourceforge.net/projects/angels-95/files/latest/download` resolves to a
playable artifact instead of a bare client binary.
