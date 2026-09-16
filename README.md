# librobot

`librobot` is a shared C++ library for the RMR robot interfaces. It supports Windows x64, Ubuntu 24.04 x64, and macOS 15 arm64. The installed CMake package exports `librobot::librobot`.

## Prerequisites

The project requires CMake 3.21 or newer, a C++20 compiler, and Qt 6.5 or newer with the Core and Network components. CI and official packages use Qt 6.8.3 (the supported 6.8.x line). Qt and OpenCV are prerequisites; release packages do not bundle them.

Camera support requires OpenCV 4.x. Official Windows packages use the official OpenCV 4.14.0 MSVC x64 distribution and the MSVC 2022 x64 Qt kit. Ubuntu packages use Ubuntu 24.04's `libopencv-dev`. macOS packages use the Homebrew `opencv` formula version recorded in `share/librobot/build-manifest.txt` inside the archive. Every package manifest records the exact OS, architecture, compiler, Qt, and OpenCV versions used to build it.

Verify the adjacent `.sha256` file before installing a downloaded release. On Windows, compare `Get-FileHash -Algorithm SHA256 <package>` with the first value in `<package>.sha256`. On Ubuntu use `sha256sum --check <package>.sha256`; on macOS use `shasum -a 256 --check <package>.sha256`.

## One-time installation

### Windows 10 or newer, x64

1. Install Visual Studio 2022 Build Tools with the Desktop development with C++ workload.
2. Install the Qt 6.8.x MSVC 2022 x64 kit. MinGW Qt kits are not supported.
3. Download and extract the official `opencv-4.14.0-windows.exe` package. Keep its `opencv\build\x64\vc17\bin` directory on your user `PATH` so the OpenCV runtime is available.
4. Run the release `.exe` installer. It installs for the current user under `%LOCALAPPDATA%\librobot`, adds its `bin` directory to the user `PATH`, and sets the stable user variable `LIBROBOT_ROOT` to that installation.
5. Open a new terminal or restart Qt Creator so it sees the updated environment.

The installer and portable ZIP are unsigned, so Windows SmartScreen may show an unknown-publisher warning. Verify the SHA-256 file and release origin before choosing to run the installer. The Windows package contains both Debug and Release libraries; CMake selects the matching configuration.

Uninstall through Windows Installed apps or run `%LOCALAPPDATA%\librobot\Uninstall.exe`. Uninstall removes the installed files, its user `PATH` entry, and `LIBROBOT_ROOT`. It does not change a machine-wide or global `CMAKE_PREFIX_PATH`.

For the portable ZIP, extract it to a stable directory, set `LIBROBOT_ROOT` to that directory with `setx LIBROBOT_ROOT "C:\path\to\librobot"`, and add its `bin` directory to your user `PATH`. Remove those two user settings and the extracted directory to uninstall it.

### Ubuntu 24.04, x64

Install prerequisites and the Release DEB once:

```sh
sudo apt update
sudo apt install qt6-base-dev libopencv-dev
sudo apt install ./librobot-1.1.0-Linux.deb
```

The DEB installs under `/usr`, so consumers can normally use `find_package(librobot REQUIRED)` without another hint. It is managed by the normal `apt`/`dpkg` package database. If a tool requires an explicit stable prefix, set `LIBROBOT_ROOT=/usr` for that tool. Uninstall with:

```sh
sudo apt remove librobot
```

The portable TGZ contains the same `/usr`-relative layout. Install it with `sudo tar -xzf librobot-1.1.0-Linux.tar.gz -C / && sudo ldconfig`. To uninstall that archive, remove only its installed librobot entries:

```sh
sudo rm -f /usr/lib/liblibrobot.so /usr/lib/liblibrobot.so.1 /usr/lib/liblibrobot.so.1.1.0
sudo rm -rf /usr/include/librobot /usr/lib/cmake/librobot /usr/share/librobot
sudo ldconfig
```

### macOS 15, Apple silicon

Install prerequisites with Homebrew, then extract the unsigned arm64 TGZ and run its scripts:

```sh
brew install qt@6 opencv
tar -xzf librobot-1.1.0-Darwin.tar.gz
sudo ./install.sh
export LIBROBOT_ROOT=/usr/local
```

Qt must be at least Qt 6.5; official CI uses Qt 6.8.3. The archive and scripts are unsigned because no Apple Developer ID is available. After verifying SHA-256 and the release origin, Finder or Gatekeeper may require you to approve the download in Privacy & Security. Do not bypass that warning for an unverified archive.

Uninstall only the files installed by this archive with `sudo ./uninstall.sh`. Remove any `LIBROBOT_ROOT=/usr/local` line you added to your shell profile. Homebrew Qt and OpenCV remain shared prerequisites and are not removed by the script.

## Use from CMake

Downstream projects may prefer the stable installation variable without changing global CMake state:

```cmake
if(DEFINED ENV{LIBROBOT_ROOT})
    list(PREPEND CMAKE_PREFIX_PATH "$ENV{LIBROBOT_ROOT}")
endif()
find_package(librobot 1.1 REQUIRED)
target_link_libraries(my_application PRIVATE librobot::librobot)
```

Do not set or mutate a global `CMAKE_PREFIX_PATH`. `LIBROBOT_ROOT` is the single persistent installation hint; the small prepend above is local to one configure operation.

## Source builds and features

Public source builds keep private AMCL disabled and support OpenCV ON or OFF:

```sh
cmake -S . -B build \
  -DLIBROBOT_ENABLE_AMCL=OFF \
  -DLIBROBOT_ENABLE_OPENCV=ON \
  -DBUILD_TESTING=ON
cmake --build build --config Release
ctest --test-dir build -C Release --output-on-failure
```

The feature variables are:

- `LIBROBOT_ENABLE_AMCL` — defaults to `OFF`; public builds need no access to AMCL.
- `LIBROBOT_ENABLE_OPENCV` — defaults to `ON`; set it to `OFF` for a camera-free build.
- `BUILD_TESTING` — enables the automated test suite when this is the top-level project.

On Windows, select `-G "Visual Studio 17 2022" -A x64`, use the matching Qt kit, and pass `-DOpenCV_DIR=C:\path\to\opencv\build\x64\vc17\lib` when discovery needs help. On macOS, per-configure hints such as `-DQt6_DIR="$(brew --prefix qt@6)/lib/cmake/Qt6"` and `-DOpenCV_DIR="$(brew --prefix opencv)/lib/cmake/opencv4"` are preferable to a global prefix-path change.

Authorized AMCL developers may use an approved local checkout of the immutable AMCL `v1.0.0` source instead of network fetching:

```sh
cmake -S . -B build \
  -DLIBROBOT_ENABLE_AMCL=ON \
  -DLIBROBOT_ENABLE_OPENCV=ON \
  -DFETCHCONTENT_SOURCE_DIR_AMCL=/absolute/path/to/authorized/amcl
```

The override must point to the authorized `v1.0.0` checkout (commit `dc39c300ec2bb60cae13603a5cae460e325f6c26`). Do not copy, publish, cache, or include private AMCL source or build trees in public artifacts. Official trusted builds fail if that pinned private checkout is unavailable.

Automated tests use local deterministic fixtures and localhost networking only. They do not contact robot, lidar, or camera hardware.
