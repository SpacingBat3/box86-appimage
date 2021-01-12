#!/bin/bash
#
#  build.sh
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

# GOTO: Variables:

GIT_REPO="https://github.com/ptitSeb/box86.git"
HERE="$(dirname "`which "$0"`")"
ME="$(basename "$0" .sh)"
OLD_WORKDIR="$PWD"
ID="${UID}:$(id -g ${USER})"
PLATFORM_LIST=('Raspberry Pi (2/3/4)' 'RK3399' 'ODROID' 'Gameshell' 'Pandora' 'Pyra')
LIB_MODE_ARR=('Copy all files.' 'Copy ".so" libraries.'
              'Copy only necessary libraries.')
AL_LIB_REQUIRED=('glibc' 'gcc-libs')

# GOTO: External scripts
hash -p "${HERE}/tools/gen-appimage.sh" gen-appimage

# Functions:
chroot(){
    sudo -p "[chroot] Enter your password: " "${HERE}/tools/chroot.sh" \
    "${CHROOT_DIR}" "${HERE}" "${UID}" "$@"
}

help(){
    y="$((${#LIB_MODE_ARR[@]}-1))"; x="[0-${x:0:21}]"
    printf -v x %-21.21s "$x"
    usage
    echo -e "\n\e[1;4mVARIABLES:\e[0m"
    echo -e " \e[1;94m->\e[0m \e[1mARCH=\e[0m[aarch64/armv7(l/h)]         \e[2mBOX86 target CPU architecture\e[0m"
    echo -e "                                      \e[2m(default: host arch = `uname -m`).\e[0m"
    echo -e " \e[1;94m->\e[0m \e[1mBUILD_PLATFORM=\e[0m[PLATFORM]         \e[2mOverwrites PLATFORM to optimize the\e[0m"
    echo -e "                                      \e[2mbuild for (default: host).\e[0m"
    echo -e " \e[1;94m->\e[0m \e[1mCHROOT_DIR=\e[0m[PATH]                 \e[2mSets the ARMHF chroot path which will\e[0m"
    echo -e "                                      \e[2mbe used to compile box86 on AARCH64\e[0m"
    echo -e "                                      \e[2mhost.\e[0m"
    echo -e " \e[1;94m->\e[0m \e[1mCP_LIB_MODE=\e[0m${x} \e[2mSets the mode of filtering libraries.\e[0m"
    echo -e " \e[1;94m->\e[0m \e[1mRESET=\e[0m[STEP]                      \e[2mRestart the build from this STEP.\e[0m"
    echo
    echo "You can also prefix the variable name with the \"BOX86_APPIMAGE_\" if you want"
    echo "to save it as an enviroment variable and you are aware the regural variable"
    echo "names will be in conflict with variables used by the other software." 
    echo -e "\n\e[1;4mPLATFORMS:\e[0m"
    printf -v PLATFORM_ALL '%s, ' "${PLATFORM_LIST[@]}"
    echo -e " \e[1;92m✓\e[0m ${PLATFORM_ALL%, }"
    echo
    x=0
    echo -e "\e[1;4mLIBRARY FILTERS:\e[0m"
    until [[ "$x" -gt "$[${#LIB_MODE_ARR[@]}-1]" ]]; do
        printf " \e[1m%s\e[0m = %s\n" "$x" "${LIB_MODE_ARR[$x]}"
        let x++
    done
    echo -e "\nThese values also indidicates the disk space usage by the libraries inside"
    echo "the AppImage – where 0 indicates the lowest disk space usage and ${y} – the"
    echo "highest."
    echo -e "\nPlease note that this variable shouldn't be set to the highest value unless"
    echo "you want to provide the libraries by yourself outside the AppImage (which"
    echo "generally takes more disk space because AppImages are compressed) or you"
    echo "would like to use the Appimage as a dependency to package X86 binary on"
    echo "AARCH64 distributables."
    echo
}

usage(){
    echo -e "\n\e[1mUSAGE\e[0m: `basename $0` [FOO=BAR]..."
    echo -e "\n\e[1;4mARGUMENTS:\e[0m"
    echo -e " -h   --help                          \e[2mDisplay entire help message.\e[0m"
    echo -e " -u   --usage                         \e[2mDisplay script usage.\e[0m"
}

error(){
    echo; printf "\nERROR: "
    case "$1" in
        1)  echo "Build method: \"${build_method}\" not implemented yet!"           ;;
        2)  echo "GIT was not installed!"                                           ;;
        3)  echo "Unsupported linux distrinution!"                                  ;;
        4)  echo "Unsupported Raspberry Pi device!"                                 ;;
        5)  echo "Missing dependency: ${dependends}!"                               ;;
        6)  echo "Source file/directory not found!"                                 ;;
        7)  echo "Couldn't get all sources!"                                        ;;
        8)  echo "Unsupported architecture ${ARCH}!"                                ;;
        9)  echo "An error occured while ${2}!"                                     ;;
        10) echo "Unimplemented selection!"                                         ;;
        *) 
            echo "Unknown error!"
            echo "Exit code ${1}!"
        ;;
    esac
    echo; exit "$1"
}

workdirs(){
    [[ ! -d "${HERE}/src" ]] && mkdir "${HERE}/src"
    [[ -f "${HERE}/build/CMakeCache.txt" ]] && rm -f "${HERE}/build/CMakeCache.txt"
    [[ -d "${HERE}/final.AppDir" ]] && rm -Rf "${HERE}/final.AppDir" >/dev/null 2>&1
}

cleanup() {
    printf "\nRemoving unnecessary \"*.AppDir\" folders..."
    [[ -d "${HERE}/final.AppDir" ]] && rm -Rf "${HERE}/final.AppDir" >/dev/null 2>&1
    [[ -d "${HERE}/box86.AppDir" ]] && rm -Rf "${HERE}/box86.AppDir" >/dev/null 2>&1
    echo " Done!"
}

cleanup_all(){
    printf "\n"
}

get_sources(){
    rmdir "${HERE}/src/box86" >/dev/null 2>&1
    if [[ -d "${HERE}/src/box86" ]]; then
        printf "\nUpdating GIT Repository..."
        git -C "${HERE}/src/box86" pull origin master >/dev/null 2>&1
        error="$?"; [[ "$error" == 0 ]] && echo -e " Done!\n" || error 7
    else
        mkdir "${HERE}/src/box86"
        git clone "${GIT_REPO}" "${HERE}/src/box86" >/dev/null 2>&1
        error="$?"; [[ "$error" == 0 ]] && echo -e " Done!\n" || error 7
    fi
    [[ -d "${HERE}/base.AppDir" ]] || error 6
}

get_device_info(){
    case "${BUILD_PLATFORM:-$(cat /proc/cpuinfo)}" in
        # Raspberry Pi SBCs
        *"Raspberry Pi"*)
            pi_model="$(tr -d '\0' </proc/device-tree/model)"
            case "$pi_model" in
                *"Raspberry Pi 4"*) pi_ver=4 ;;
                *"Raspberry Pi 3"*) pi_ver=3 ;;
                *"Raspberry Pi 2"*) pi_ver=2 ;;
                *) error 4 # RPi 1/0 are not supported, cancel building.
            esac
            platform="rpi${pi_ver}" # used for artifact name
            cmake_flags=("-DRPI${pi_ver}=1")
        ;;
        # Other ARM Boards
        *"RK3399"*)    platform='rk3399';    cmake_flags=('-DRK3399=1')       ;;
        *"ODROID"*)    platform='odroid';    cmake_flags=('-DODROID=1')       ;;
        *"Gameshell"*) platform='gameshell'; cmake_flags=('-DGAMESHELL=1')    ;;
        *"Pandora"*)   platform='pandora';   cmake_flags=('-DPANDORA=1')      ;;
        *"Pyra"*)      platform='pyra';      cmake_flags=('-DPYRA=1')         ;;
        *)             platform='arm';       cmake_flags=('-DARM_DYNAREC=ON') ;;
    esac
}

build_32(){
    # TODO: Build script for 32-bit OS.
    echo
}

package_appimage_32(){
    # TODO: Package script for the 32-bit OS.
    echo
}

create_chroot(){
    # TODO: A script to create an chroot enviroment on the Arch Linux.
    [[ -f /etc/pacman.conf && -f /etc/makepkg.conf ]] || error 3    
}

build_chroot(){
    if [[ -z "$CHROOT_DIR" ]]; then
        until [[ ! -z "$LOOP_END" && "$LOOP_END" != 0 ]]; do
            read -ep 'Enter the "armv7h" chroot path: ' CHROOT_DIR
            if [[ ! -d "$CHROOT_DIR" ]]; then
                echo "$CHROOT_DIR isn't a directory!"
                echo "Please type the correct path to the directory."
            elif [[ ! -d "$CHROOT_DIR/bin" && ! -d "$CHROOT_DIR/lib" ]] && \
                 [[ ! -d "$CHROOT_DIR/usr" && ! -d "$CHROOT_DIR/var" ]]; then
                echo "$CHROOT_DIR isn't the root folder!"
            else
                LOOP_END=1
            fi
        done
    fi
    unset LOOP_END
    LD_LIBRARY_PATH="${CHROOT_DIR}/lib:${LD_LIBRARY_PATH}"
    BIN32="${CHROOT_DIR}/usr/bin"
    INT32="${CHROOT_DIR}/lib/ld-linux-armhf.so.3"
    check_dependencies --chroot make cmake gcc g++
    flags="${cmake_flags[@]}" chroot /usr/bin/bash -c \
        'cd /mnt/; mkdir build >/dev/null 2>&1; cd build; \
        cmake "../src/box86" $flags -DCMAKE_BUILD_TYPE=RelWithDebInfo; \
        make -j$(nproc)'
    PACKAGE_MODE=0
}

build_toolchain(){
    echo "Does not work :("
    # TODO: Toolchain build method.
}

check_dependencies(){
    if [[ "$1" =~ "chroot" ]]; then
        for depends in "${@:2}"; do
            [[ -f "${BIN32}/${depends}" ]] || error 5
        done
    else
        for depends in "${@}"; do
            which "$depends" >/dev/null 2>&1 || error 5
        done
    fi
}

install_box86(){
    case "$PACKAGE_MODE" in
        0)
            pkgdir="${HERE}/final.AppDir/usr"
            install -Dm755 "${HERE}/build/box86" "${pkgdir}/bin/box86"
            [[ ! -d "${pkgdir}/lib/i386-linux-gnu" ]] && mkdir -p "${pkgdir}/lib/i386-linux-gnu"
            cp -Rpt "${pkgdir}/lib/i386-linux-gnu" "${HERE}/src/box86/x86lib/"*
            chmod 755 "${pkgdir}/lib/i386-linux-gnu"
            chmod -R 644 "${pkgdir}/lib/i386-linux-gnu/"*
            install -Dm644 "${HERE}/src/box86/LICENSE" "${pkgdir}/share/licenses/box86/LICENSE"
        ;;
    esac
    
}

install_libs(){
    case "$PACKAGE_MODE" in
    0)
        if [[ "$CP_LIB_MODE" > 0 ]] && [[ "$CP_LIB_MODE" < "${#LIB_MODE_ARR[@]}" ]] && [ "$CP_LIB_MODE" -eq "$CP_LIB_MODE" ] 2>/dev/null ; then
            lib_mode="${LIB_MODE_ARR[$CP_LIB_MODE]}"
        else
            echo "Select mode: "
            select lib_mode in "${LIB_MODE_ARR[@]}"; do
                [[ ! -z $lib_mode ]] && break
            done
        fi
        printf "\nCopying the \`/lib\` content from the current chroot..."
        [[ ! -d "${HERE}/final.AppDir/usr/lib/" ]] && mkdir -p "${HERE}/final.AppDir/usr/lib/"
        case "$lib_mode" in
            *'all files'*)
                sudo cp -at "${HERE}/final.AppDir/usr/lib/" "${CHROOT_DIR}/usr/lib/"*
                error="$?"
            ;;
            *'".so" files'*)
                cd "${CHROOT_DIR}/usr/lib/"
                readarray -d '' LIB_FILES < <(sudo find * ! -type d -name '*.so' -print0 -o ! -type d -name '*.so.*' -print0)
                for file in "${LIB_FILES[@]}"; do
                    sudo cp --parents -at "${HERE}/final.AppDir/usr/lib/" "${file}"
                done
                error="$?"
                cd "${OLD_WORKDIR}"
            ;;
            *'necessary lib'*)
                #FIXME: Debian CHROOT support (and probably others too):
                if [[ -f /etc/pacman.conf && -f "${CHROOT_32}/etc/pacman.conf" ]]; then
                    readarray LIB_FILES < <(pacman -Qlr  "$CHROOT_DIR" "${AL_LIB_REQUIRED[@]}" | awk '{print $2}' | grep usr/lib | sed "s.$CHROOT_DIR/usr/lib/..g")
                elif [[ -f "${CHROOT_32}/etc/pacman.conf" ]]; then
                    readarray LIB_FILES < <(chroot env LIBS=("${AL_LIB_REQUIRED[@]}") /usr/bin/bash -c 'pacman -Ql "${LIBS[@]}" | awk {print\ \$2} | grep usr/lib | sed s./usr/lib/..g ' )
                else
                    error 3
                fi
                cd "${CHROOT_DIR}/usr/lib/"
                for file in "${LIB_FILES[@]}"; do
                    file="$(tr -d '\n' <<<"${file}")"
                    if [[ -f "$file"  ]] && [[ "$file" == *'.so' || "$file" == *'.so.'* ]]; then
                        sudo cp --parents -at "${HERE}/final.AppDir/usr/lib/" "${file}"
                    fi
                done
                error="$?"
            ;;
            *) error 10 ;;
        esac
        [[ "$error" == 0 ]] && echo -e " Done!\n" || error 9 "copying libraries from the current chroot"
        sudo -p "[chown] Enter your password: " chown -R "$ID" "${HERE}/final.AppDir/usr/lib/"
        find "${HERE}/final.AppDir/usr/lib/" -xtype l -delete
    ;;
    1)
        #TODO: Install libs from the toolchain enviroment.
        echo "TODO!" 
    ;;
    esac
}

package_appimage(){
    if [[ -d "${HERE}/final.AppDir" ]]; then
        cp -Rt "${HERE}/final.AppDir" "${HERE}/base.AppDir/"*
        [[ -d "${HERE}/box86.AppDir" ]] && rm -Rf "${HERE}/box86.AppDir"
        mv "${HERE}/final.AppDir" "${HERE}/box86.AppDir"
    fi
}

# GOTO: Parse arguments.
argv=()
for var in ${@}; do
    case "$var" in
    -*h*|--"help") help; exit 0 ;;
    -*u*|"--usage") usage; echo; exit 0 ;;
    *?*"="*) declare "${var}" ;;
    *) argv+=("$var") ;;
    esac
done
unset var

ARCH="${ARCH:-${BOX86_APPIMAGE_ARCH:-$(uname -m)}}"
BUILD_PLATFORM="${BUILD_PLATFORM:-${BOX86_APPIMAGE_BUILD_PLATFORM}}"
CHROOT_DIR="${CHROOT_DIR:-${BOX86_APPIMAGE_CHROOT_DIR}}"
CP_LIB_MODE="${CP_LIB_MODE:-${BOX86_APPIMAGE_CP_LIB_MODE}}"
RESET="${APPIMAGE_RESET:-${BOX86_APPIMAGE_RESET}}"

# FIXME: Currently there's no support for the 32-bit build type.

# Main part of the script
get_device_info
PS3_DEFAULT="$PS3"
PS3="Enter number: "
if [[ ! -z "$RESET" ]]; then
    case "$RESET" in
        *"package"*) package_appimage; ARCH="$ARCH" gen-appimage "${HERE}/box86.AppDir" "${HERE}/dist/box86-${ARCH}-${platform}.AppImage" ;;
    esac
    exit 0
fi
if [[ "$(uname -m)" == "aarch64" ]]; then
    echo "Which method will you use to build the BOX86 with on the `uname -m` host?"
    select build_method in "with chroot" "with toolchain" "create new chroot"; do
        if [[ ! -z "$build_method" ]]; then
            check_dependencies 'git' 'arch-chroot'
            workdirs; get_sources
            echo "Platform: \"$(printf "${platform}" | tr a-z A-Z )\"."
            echo -e "CMAKE flags: ${cmake_flags[@]}\n"
            case "$build_method" in 
                "with chroot") build_chroot ;;
                #"with toolchain") build_toolchain ;;
                #"create new chroot") create_chroot; build_chroot ;;
                *) error 1 ;;
            esac
            install_box86;
            [[ "$ARCH" == "aarch64" ]] && install_libs
            package_appimage; ARCH="$ARCH" gen-appimage "${HERE}/box86.AppDir" "${HERE}/dist/box86-${ARCH}-${platform}.AppImage"
            cleanup
            break
        fi
    done
elif [[ "$(uname -m)" == "armv7h" || "$(uname -m)" == "armv7l" ]]; then
    # TODO: Package on the ARMv7 hosts.
    error 8
else
    error 8
fi
PS3="$PS3_DEFAULT"
unset PS3_DEFAULT
hash -r
exit 0