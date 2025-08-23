#!/bin/sh

set -eux

ARCH="$(uname -m)"
REPO="https://github.com/alacritty/alacritty.git"
EXTRA_PACKAGES="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/get-debloated-pkgs.sh"
GRON="https://raw.githubusercontent.com/xonixx/gron.awk/refs/heads/main/gron.awk"
PATCH="$PWD"/hack.patch

echo "Installing build dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	base-devel          \
	cargo               \
	cmake               \
	curl                \
	fontconfig          \
	freetype2           \
	gdb                 \
	git                 \
	libxcb              \
	libxcursor          \
	libxi               \
	libxkbcommon        \
	libxkbcommon-x11    \
	libxrandr           \
	libxtst             \
	mesa                \
	ncurses             \
	patch               \
	rust                \
	scdoc               \
	strace              \
	wget                \
	xorg-server-xvfb    \
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
echo "$VERSION" > ~/version

# We need to build alacritty here and not later as it turns out rust sucks and will fail with this error when using the smaller llvm
# rustc: symbol lookup error: /usr/lib/librustc_driver-fa1421cc2e9f32b2.so: undefined symbol: LLVMInitializeARMTargetInfo, version LLVM_20.1
echo "Building alacritty..."
echo "---------------------------------------------------------------"
(
	cd ./alacritty
	patch -p1 -i "$PATCH"
	cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"
	CARGO_INCREMENTAL=0 cargo build --release --locked --offline
	CARGO_INCREMENTAL=0 cargo test --locked --offline
)

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
chmod +x ./get-debloated-pkgs.sh
./get-debloated-pkgs.sh --add-opengl
