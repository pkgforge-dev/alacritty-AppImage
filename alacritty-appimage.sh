#!/bin/sh

set -ex

ARCH="$(uname -m)"
REPO="https://github.com/alacritty/alacritty.git"
GRON="https://raw.githubusercontent.com/xonixx/gron.awk/refs/heads/main/gron.awk"
URUNTIME="https://github.com/VHSgunzo/uruntime/releases/latest/download/uruntime-appimage-dwarfs-$ARCH"
SHARUN="https://github.com/VHSgunzo/sharun/releases/latest/download/sharun-$ARCH-aio"
UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"

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

# build alacritty
(
	cd ./alacritty
	#patch -p1 -i ./hack.patch
	cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"
	CARGO_INCREMENTAL=0 cargo build --release --locked --offline
	#CARGO_INCREMENTAL=0 cargo test --locked --offline

)


# Prepare AppDir
mkdir -p ./AppDir/shared/bin
cp -v ./alacritty/extra/linux/Alacritty.desktop        ./AppDir
cp -v ./alacritty/extra/logo/compat/alacritty-term.svg ./AppDir
cp -v ./alacritty/extra/logo/compat/alacritty-term.svg ./AppDir/.DirIcon
cp -v ./alacritty/target/release/alacritty ./AppDir/shared/bin 

rm -rf ./alacritty && ( 
	cd ./AppDir
	# ADD LIBRARIES
	wget --retry-connrefused --tries=30 "$SHARUN" -O ./sharun-aio
	chmod +x ./sharun-aio
	xvfb-run -a -- \
		./sharun-aio l -p -v -e -s -k \
		./shared/bin/alacritty        \
		/usr/lib/lib*GL*              \
		/usr/lib/dri/*                \
		/usr/lib/gbm/*                \
		/usr/lib/libXss.so*           \
		/usr/lib/pulseaudio/*
	
	# Prepare sharun
	echo 'unset ARGV0' > ./.env
	ln ./sharun ./AppRun
	./sharun -g
)

# MAKE APPIMAGE WITH URUNTIME
wget --retry-connrefused --tries=30 "$URUNTIME"      -O  ./uruntime
wget --retry-connrefused --tries=30 "$URUNTIME_LITE" -O  ./uruntime-lite
chmod +x ./uruntime*

# Add udpate info to runtime
echo "Adding update information \"$UPINFO\" to runtime..."
./uruntime-lite --appimage-addupdinfo "$UPINFO"

# Keep the mount point (speeds up launch time)
sed -i 's|URUNTIME_MOUNT=[0-9]|URUNTIME_MOUNT=0|' ./uruntime

echo "Generating AppImage..."
./uruntime \
	--appimage-mkdwarfs -f               \
	--set-owner 0 --set-group 0          \
	--no-history --no-create-timestamp   \
	--compression zstd:level=22 -S26 -B8 \
	--header uruntime-lite               \
	-i ./AppDir                          \
	-o ./alacritty-"$VERSION"-anylinux-"$ARCH".AppImage

# make appbundle
UPINFO="$(echo "$UPINFO" | sed 's#.AppImage.zsync#*.AppBundle.zsync#g')"
wget --retry-connrefused --tries=30 \
	"https://github.com/xplshn/pelf/releases/latest/download/pelf_$ARCH" -O ./pelf
chmod +x ./pelf
echo "Generating [dwfs]AppBundle..."
./pelf \
	--compression "-C zstd:level=22 -S26 -B8"      \
	--appbundle-id="alacritty-$VERSION"            \
	--appimage-compat --disable-use-random-workdir \
	--add-updinfo "$UPINFO"                        \
	--add-appdir ./AppDir                          \
	--output-to ./alacritty-$VERSION-anylinux-$ARCH.dwfs.AppBundle"

zsyncmake ./*.AppImage -u ./*.AppImage
zsyncmake ./*.AppBundle -u ./*.AppBundle
echo "All Done!"
