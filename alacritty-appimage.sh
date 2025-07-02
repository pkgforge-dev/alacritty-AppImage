#!/bin/sh

set -ex

ARCH="$(uname -m)"
URUNTIME="https://github.com/VHSgunzo/uruntime/releases/latest/download/uruntime-appimage-dwarfs-$ARCH"
URUNTIME_LITE="https://github.com/VHSgunzo/uruntime/releases/latest/download/uruntime-appimage-dwarfs-lite-$ARCH"
SHARUN="https://github.com/VHSgunzo/sharun/releases/latest/download/sharun-$ARCH-aio"
UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"

# Prepare AppDir
mkdir -p ./AppDir/shared/bin
cp -v ./alacritty/target/release/alacritty             ./AppDir/shared/bin 
cp -v ./alacritty/extra/linux/Alacritty.desktop        ./AppDir
cp -v ./alacritty/extra/logo/compat/alacritty-term.svg ./AppDir
cp -v ./alacritty/extra/logo/compat/alacritty-term.svg ./AppDir/.DirIcon

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

# Keep the mount point (speeds up launch time)
sed -i 's|URUNTIME_MOUNT=[0-9]|URUNTIME_MOUNT=0|' ./uruntime-lite

# Add udpate info to runtime
echo "Adding update information \"$UPINFO\" to runtime..."
./uruntime-lite --appimage-addupdinfo "$UPINFO"

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
	--output-to ./alacritty-"$VERSION"-anylinux-"$ARCH".dwfs.AppBundle

zsyncmake ./*.AppImage -u ./*.AppImage
zsyncmake ./*.AppBundle -u ./*.AppBundle
echo "All Done!"
