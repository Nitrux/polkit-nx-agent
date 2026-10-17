#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
PACKAGE_VERSION="${PACKAGE_VERSION:?PACKAGE_VERSION must be supplied by CI}"
TARGET_ARCH="${TARGET_ARCH:-$(dpkg --print-architecture)}"

source_dir="$repo_root"

# MauiKit software MUST be built with CMake and ECM; NEVER use Meson.
build_dir="$repo_root/build"
cmake_dir="$build_dir/cmake"
stage_dir="$build_dir/package"
rm -rf "$cmake_dir" "$stage_dir"
mkdir -p "$build_dir"

cmake_args=(
    -DCMAKE_INSTALL_PREFIX=/usr
    -DKDE_INSTALL_LIBDIR="lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
    -DCMAKE_BUILD_TYPE=Release
)
if [ "$(dpkg-architecture -qDEB_HOST_ARCH)" = "amd64" ]; then
    cmake_args+=(-DCMAKE_CXX_FLAGS=-march=x86-64-v3)
fi

cmake -S "$source_dir" -B "$cmake_dir" "${cmake_args[@]}"
cmake --build "$cmake_dir" --parallel "$(nproc)"
DESTDIR="$stage_dir" cmake --install "$cmake_dir"

mkdir -p "$stage_dir/DEBIAN"
cat > "$stage_dir/DEBIAN/control" <<CONTROL
Package: polkit-nx-agent
Version: ${PACKAGE_VERSION}
Section: admin
Priority: optional
Architecture: ${TARGET_ARCH}
Maintainer: uri_herrera@nxos.org
Provides: polkit-nx-agent
Depends: libkf6i18n6,libqt6core6t64,libqt6gui6,libqt6qml6,libqt6quick6,mauikit (>= 4.0.5),polkitd,libpolkit-qt6-1-1,qml6-module-qtquick,qml6-module-qtquick-controls,qml6-module-qtquick-layouts,qt6-wayland
Description: polkit-nx-agent
 polkit-nx-agent
CONTROL

dpkg-deb --build --root-owner-group "$stage_dir" "$build_dir/polkit-nx-agent_${PACKAGE_VERSION}_${TARGET_ARCH}.deb"
