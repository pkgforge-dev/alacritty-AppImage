#!/bin/sh

set -eux

ARCH="$(uname -m)"
REPO="https://github.com/alacritty/alacritty.git"
GRON="https://raw.githubusercontent.com/xonixx/gron.awk/refs/heads/main/gron.awk"

case "$ARCH" in
	'x86_64')  PKG_TYPE='x86_64.pkg.tar.zst';;
	'aarch64') PKG_TYPE='aarch64.pkg.tar.xz';;
	''|*) echo "Unknown arch: $ARCH"; exit 1;;
esac

LLVM_URL="https://github.com/pkgforge-dev/llvm-libs-debloated/releases/download/continuous/llvm-libs-nano-$PKG_TYPE"
MESA_URL="https://github.com/pkgforge-dev/llvm-libs-debloated/releases/download/continuous/mesa-mini-$PKG_TYPE"
LIBXML_URL="https://github.com/pkgforge-dev/llvm-libs-debloated/releases/download/continuous/libxml2-iculess-$PKG_TYPE"
OPUS_URL="https://github.com/pkgforge-dev/llvm-libs-debloated/releases/download/continuous/opus-nano-$PKG_TYPE"

echo "Installing build dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	base-devel \
	cargo \
	cmake \
	curl \
	desktop-file-utils \
	fontconfig \
	freetype2 \
	gdb \
	git \
	libxcb \
	libxcursor \
	libxi \
	libxkbcommon \
	libxkbcommon-x11 \
	libxrandr \
	libxtst \
	mesa    \
	ncurses \
	patchelf \
	pipewire-audio \
	pulseaudio \
	pulseaudio-alsa \
	rust \
	scdoc \
	strace \
	wget \
	xorg-server-xvfb \
	zsync

# Determine to build nightly or stable
if [ "DEVEL" = 'true' ]; then
	echo "Making nightly build of alacritty..."
	VERSION="$(git ls-remote "$REPO" HEAD | cut -c 1-9)"
	git clone --recursive -j$(nproc) "$REPO" ./alacritty
else
	echo "Making stable build of alacritty..."
	wget "$GRON" -O ./gron.awk
	chmod +x ./gron.awk
	VERSION=$(wget https://api.github.com/repos/alacritty/alacritty/tags -O - \
		| ./gron.awk | awk -F'=|"' '/name/ {print $3; exit}')
	git clone --recursive -j$(nproc) --branch "$VERSION" --single-branch "$REPO" ./alacritty
fi

# We need to build alacritty here and not later as it turns out rust sucks and will fail with this error when using the smaller llvm
# rustc: symbol lookup error: /usr/lib/librustc_driver-fa1421cc2e9f32b2.so: undefined symbol: LLVMInitializeARMTargetInfo, version LLVM_20.1
echo "Building alacritty..."
echo "---------------------------------------------------------------"
(
	cd ./alacritty
	#patch -p1 -i ./hack.patch
	cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"
	CARGO_INCREMENTAL=0 cargo build --release --locked --offline
	#CARGO_INCREMENTAL=0 cargo test --locked --offline
	echo "$VERSION" > ~/version
)


echo "Installing debloated pckages..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$LLVM_URL"   -O  ./llvm-libs.pkg.tar.zst
wget --retry-connrefused --tries=30 "$MESA_URL"   -O  ./mesa.pkg.tar.zst
wget --retry-connrefused --tries=30 "$LIBXML_URL" -O  ./libxml2.pkg.tar.zst
wget --retry-connrefused --tries=30 "$OPUS_URL"   -O  ./opus.pkg.tar.zst

pacman -U --noconfirm ./*.pkg.tar.zst
rm -f ./*.pkg.tar.zst


echo "All done!"
echo "---------------------------------------------------------------"
