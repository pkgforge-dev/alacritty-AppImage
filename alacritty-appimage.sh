#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.bg.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"

# Deploy dependencies
quick-sharun ./AppDir/bin/alacritty /usr/lib/libedit.so*

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage
