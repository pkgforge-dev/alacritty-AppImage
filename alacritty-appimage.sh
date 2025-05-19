#!/bin/sh

set -eu

PACKAGE=alacritty
DESKTOP=Alacritty.desktop
ICON=Alacritty.svg

export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1
export VERSION=$(pacman -Q "$PACKAGE" | awk 'NR==1 {print $2; exit}')
echo "$VERSION" > ~/version

UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
URUNTIME="https://github.com/VHSgunzo/uruntime/releases/latest/download/uruntime-appimage-dwarfs-$ARCH"
# Prepare AppDir
mkdir -p ./AppDir
cd ./AppDir

cp -v /usr/share/applications/"$DESKTOP" ./
cp -v /usr/share/pixmaps/"$ICON"         ./
cp -v /usr/share/pixmaps/"$ICON"         ./.DirIcon

# ADD LIBRARIES
wget "$LIB4BN" -O ./lib4bin
chmod +x ./lib4bin
xvfb-run -d -- ./lib4bin -p -v -e -s -k \
	/usr/bin/alacritty \
	/usr/lib/libEGL* \
	/usr/lib/libGL* \
	/usr/lib/dri/* \
	/usr/lib/libXss.so* \
	/usr/lib/pulseaudio/*

echo 'unset ARGV0' > ./.env

# Prepare sharun
# for some reason an AppRun script is needed here
# hardlinks nor symlinks to sharun work
echo '#!/bin/sh
CURRENTDIR="$(readlink -f "$(dirname "$0")")"
exec "$CURRENTDIR"/bin/alacritty "$@"' > ./AppRun
chmod +x ./AppRun

./sharun -g

# MAKE APPIMAGE WITH URUNTIME
cd ..
wget -q "$URUNTIME" -O ./uruntime
chmod +x ./uruntime

#Add udpate info to runtime
echo "Adding update information \"$UPINFO\" to runtime..."
./uruntime --appimage-addupdinfo "$UPINFO"

echo "Generating AppImage..."
./uruntime --appimage-mkdwarfs -f \
	--set-owner 0 --set-group 0 \
	--no-history --no-create-timestamp \
	--compression zstd:level=22 -S26 -B8 \
	--header uruntime \
	-i ./AppDir -o "$PACKAGE"-"$VERSION"-anylinux-"$ARCH".AppImage

echo "Generating zsync file..."
zsyncmake *.AppImage -u *.AppImage

echo "All Done!"
