#!/bin/sh
#
#  gen-appimage.sh
#
#  Package the "AppDir" to the AppImage format.
#
#  Copyright (C) 2021 SpacingBat3
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#

# Functions:
cleanup(){
    printf "Cleanup..."
    rm "${tmp}/.${tmpname}-1.${tmpext}"
    rm "${tmp}/.${tmpname}-2.${tmpext}"
    echo " Done!"
    
}
error() {
    echo; printf "ERROR: "
    case ${1} in
        1) echo "Unsupported arch \"${ARCH}\"!" ;;
        2) echo "Couldn't download the runtime from the internet!" ;;
        3) echo "Couldn't generate the SQUASHFS image!" ;;
        4) echo "Couldn't generate final AppImage!" ;;
        5) echo "Canceled by user!" ;;
        *) [[ "$error" == 0 || -z "$error" ]] && echo "Unknown error!";;
    esac
    printf "Exit code ${1}!"
    [[ "$error" == 0 || -z "$error" ]] && echo || echo " App returned ${error}."
    exit "${1}"
}
warn(){
    echo; printf "WARN: "
    case ${1} in
        1) echo "Couldn't generate \".DirIcon\" file!"
           echo "Please make sure that \"${2}\" exists." ;;
        *) echo "Unknown warning!" ;;
    esac
}
repo_ver() { # https://gist.github.com/lukechilds/a83e1d7127b78fef38c2914c4ececc3c
    curl --silent "https://api.github.com/repos/${1}/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/'
}

# Recognize the "$@":
if [[ -z $3 ]]; then
    flags=("-b" "1048576" "-comp" "xz" "-Xdict-size" "100%")
elif [[ "$3" =~ "quick" ]]; then
    flags=("-comp" "lzo" "-Xcompression-level" "1")
else
    flags=("${@:3}")
fi
if [[ ! -d $1 ]] || [[ -z $2 ]]; then
    echo "USAGE: `basename $0` [APPDIR] [APPIMAGE]"
    exit 0
fi

# Variables:
tmp="/tmp"
tmpext="part"
tmpname="`basename "${2}" .AppImage`"

# Detect AppImage architecture and  check it's compatibility:
SUPPORTED_ARCH=("aarch64" "armhf" "x86_64" "i386")
UNAME_ARCH="$(uname -m)"
ARCH=${ARCH:-$UNAME_ARCH}
[[ "$ARCH" =~ "armv7" ]] && ARCH="armhf"
[[ "$ARCH" == "arm64" ]] && ARCH="aarch64"
[[ "$ARCH" == "x64" || "$ARCH" == "amd64" ]] && ARCH="x86_64"
[[ "$ARCH" == "x86" || "$ARCH" =~ "pentium" || "$ARCH" == "i"?"86" ]] && ARCH="i686"
for cur_a in "${SUPPORTED_ARCH[@]}"; do
    [[ "$ARCH" == "$cur_a" ]] && error=0 || error=1
    [[ "$error" == 0 ]] && break
done
[[ "$error" == 0 ]] || error 1
REPO="AppImage/AppImageKit"
REPO_TAG="$(repo_ver $REPO)"

# Code:
printf "Generating \".DirIcon\"..."
if [[ ! -f "${1}/.DirIcon" ]]; then
    ICON="${1}/$(basename "${1}" .AppDir).png"
    if [[ -f "${ICON}" ]]; then
        IN="${1}" ICON="${ICON}" \
        bash -c 'cd "${IN}"; \
        ln -sr "$(basename "${ICON}")" ".DirIcon"'
    else
        warn 1 "${ICON}"
    fi
fi
echo " Done!"

trap 'cleanup; error 5' INT

printf "Downloading the latest \"${ARCH}\" runtime..."
wget -O "${tmp}/.${tmpname}-1.${tmpext}" -q \
--no-check-certificate --content-disposition \
"https://github.com/${REPO}/releases/download/${REPO_TAG}/runtime-${ARCH}"
error="$?"; [[ "$error" == 0 ]] && echo " Done!" || error 2

printf "Creating a SQUASHFS image..."
mksquashfs "${1}" "${tmp}/.${tmpname}-2.${tmpext}" -quiet -root-owned -noappend "${flags[@]}"
error="$?"
if [[ "$error" == 0 ]]; then
    n=0
    printf "\033[1A"
    while [[ "$n" -lt "$COLUMNS" ]]; do printf ' '; let n++; done
    echo -e "\rCreating a SQUASHFS image... Done!"
else 
    error 3 
fi

printf "Generating final AppImage..."
[[ ! -d "$(dirname "${2}")" ]] && mkdir -p "$(dirname "${2}")"
cat "${tmp}/.${tmpname}-1.${tmpext}" > "${2}"
cat "${tmp}/.${tmpname}-2.${tmpext}" >> "${2}"
chmod a+x "${2}"
error="$?"; [[ "$error" == 0 ]] && echo " Done!" || error 4
cleanup
echo -e "Successfully packaged!"
exit 0