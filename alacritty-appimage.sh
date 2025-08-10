#!/bin/sh

set -eux

ARCH="$(uname -m)"
VERSION="$(cat ~/version)"
SHARUN="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"
URUNTIME="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/uruntime2appimage.sh"
UPDATER="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/self-updater.bg.hook"

export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export OUTNAME=alacritty-"$VERSION"-anylinux-"$ARCH".AppImage

# Prepare AppDir
mkdir -p ./AppDir/shared/bin
cp -v ./alacritty/target/release/alacritty             ./AppDir/shared/bin 
cp -v ./alacritty/extra/linux/Alacritty.desktop        ./AppDir
cp -v ./alacritty/extra/logo/compat/alacritty-term.svg ./AppDir
cp -v ./alacritty/extra/logo/compat/alacritty-term.svg ./AppDir/.DirIcon
rm -rf ./alacritty 

# ADD LIBRARIES
wget --retry-connrefused --tries=30 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun
DEPLOY_OPENGL=1 ./quick-sharun ./AppDir/shared/bin/alacritty
echo 'unset ARGV0' > ./AppDir/.env
ln ./AppDir/sharun ./AppDir/AppRun

# add self updater script, run alacritty-update in alacritty to update
wget --retry-connrefused --tries=30 "$UPDATER" -O ./AppDir/bin/alacritty-update
chmod +x ./AppDir/bin/alacritty-update

# MAKE APPIMAGE WITH URUNTIME
wget --retry-connrefused --tries=30 "$URUNTIME" -O ./uruntime2appimage
chmod +x .uruntime2appimage
./uruntime2appimage

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

zsyncmake ./*.AppBundle -u ./*.AppBundle
echo "All Done!"
