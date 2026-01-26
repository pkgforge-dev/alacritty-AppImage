#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing build dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	base-devel          \
	cargo               \
	cmake               \
	fontconfig          \
	freetype2           \
	gdb                 \
	libxrandr           \
	libxtst             \
	ncurses             \
	patch               \
	rust                \
	scdoc

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
# Do not install the smaller llvm as that causes the rust compiler to cry
# rustc: symbol lookup error: /usr/lib/librustc_driver-fa1421cc2e9f32b2.so: undefined symbol: LLVMInitializeARMTargetInfo, version LLVM_20.1
get-debloated-pkgs --add-common --prefer-nano ! llvm-libs

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

REPO=https://github.com/alacritty/alacritty.git
EXTRA_PACKAGES=https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/get-debloated-pkgs.sh
GRON=https://raw.githubusercontent.com/xonixx/gron.awk/refs/heads/main/gron.awk

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

echo "Building alacritty..."
echo "---------------------------------------------------------------"
(
	cd ./alacritty
	cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"
	export CARGO_INCREMENTAL=0
	cargo build --release --locked --offline
	cargo test --locked --offline
)

mkdir -p ./AppDir/bin
mv -v ./alacritty/target/release/alacritty              ./AppDir/bin
mv -v ./alacritty/extra/linux/Alacritty.desktop         ./AppDir
cp -v ./alacritty/extra/logo/compat/alacritty-term.svg  ./AppDir
mv -v ./alacritty/extra/logo/compat/alacritty-term.svg  ./AppDir/.DirIcon
