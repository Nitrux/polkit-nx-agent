#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
PACKAGE_VERSION="${PACKAGE_VERSION:-0.0.1}"
TARGET_ARCH="${TARGET_ARCH:-$(dpkg --print-architecture)}"

source_dir="$repo_root"

build_dir="$repo_root/build"
meson_dir="$build_dir/meson"
stage_dir="$build_dir/package"
rm -rf "$meson_dir" "$stage_dir"
mkdir -p "$build_dir"

meson_args=(--prefix=/usr --buildtype=release)
if [ "$(dpkg-architecture -qDEB_HOST_ARCH)" = "amd64" ]; then
    meson_args+=("-Dcpp_args=-march=x86-64-v3")
fi

meson setup "$meson_dir" "$source_dir" "${meson_args[@]}"
meson compile -C "$meson_dir" -j "$(nproc)"
DESTDIR="$stage_dir" meson install -C "$meson_dir"

mkdir -p "$stage_dir/DEBIAN"
cat > "$stage_dir/DEBIAN/control" <<CONTROL
Package: polkit-nx-agent
Version: ${PACKAGE_VERSION}
Section: admin
Priority: optional
Architecture: ${TARGET_ARCH}
Maintainer: uri_herrera@nxos.org
Provides: polkit-nx-agent
Depends: mauikit (>= 4.0.5),polkitd,libpolkit-qt6-1-1,qml6-module-qtquick,qml6-module-qtquick-controls,qml6-module-qtquick-layouts,qt6-wayland
Description: polkit-nx-agent
 polkit-nx-agent
CONTROL

dpkg-deb --build --root-owner-group "$stage_dir" "$build_dir/polkit-nx-agent_${PACKAGE_VERSION}_${TARGET_ARCH}.deb"
