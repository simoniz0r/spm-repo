#!/bin/bash
# Title: spm
# Description: Downloads and installs AppImages and precompiled tar archives.  Can also upgrade and remove installed packages.
# Dependencies: GNU coreutils, tar, wget
# Author: simonizor
# Website: http://www.simonizor.gq
# License: GPL v2.0 only

X="0.6.4"
# Set spm version
TAR_LIST="$(cat "$CONFDIR"/tar-pkgs.yml | cut -f1 -d":")"
TAR_SIZE="N/A"
TAR_DOWNLOADS="N/A"
TAR_CLR="${CLR_CYAN}"

tarfunctionsexistfunc () {
    sleep 0
}

tarsaveconffunc () { # Saves file containing tar package info in specified directory for use later
    if [ -z "$NEW_TARFILE" ]; then
        NEW_TARFILE="$TARFILE"
    fi
    SAVEDIR="$1"
    echo "INSTDIR="\"$INSTDIR\""" > "$CONFDIR"/"$SAVEDIR"
    echo "TAR_DOWNLOAD_SOURCE="\"$TAR_DOWNLOAD_SOURCE\""" >> "$CONFDIR"/"$SAVEDIR"
    echo "TARURI="\"$TARURI\""" >> "$CONFDIR"/"$SAVEDIR"
    echo "TARFILE="\"$NEW_TARFILE\""" >> "$CONFDIR"/"$SAVEDIR"
    echo "TAR_DOWNLOADS="\"$TAR_DOWNLOADS\""" >> "$CONFDIR"/"$SAVEDIR"
    echo "TAR_SIZE="\"$TAR_SIZE\""" >> "$CONFDIR"/"$SAVEDIR"
    if [ "$TAR_DOWNLOAD_SOURCE" = "GITHUB" ]; then
        echo "TAR_GITHUB_COMMIT="\"$TAR_GITHUB_NEW_COMMIT\""" >> "$CONFDIR"/"$SAVEDIR"
        echo "TAR_GITHUB_VERSION="\"$TAR_GITHUB_NEW_VERSION\""" >> "$CONFDIR"/"$SAVEDIR"
    fi
    echo "DESKTOP_FILE_PATH="\"$DESKTOP_FILE_PATH\""" >> "$CONFDIR"/"$SAVEDIR"
    echo "ICON_FILE_PATH="\"$ICON_FILE_PATH\""" >> "$CONFDIR"/"$SAVEDIR"
    echo "EXECUTABLE_FILE_PATH="\"$EXECUTABLE_FILE_PATH\""" >> "$CONFDIR"/"$SAVEDIR"
    echo "BIN_PATH="\"$BIN_PATH\""" >> "$CONFDIR"/"$SAVEDIR"
    # echo "CONFIG_PATH="\"$CONFIG_PATH\""" >> "$CONFDIR"/"$SAVEDIR"
    echo "TAR_DESCRIPTION="\"$TAR_DESCRIPTION\""" >> "$CONFDIR"/"$SAVEDIR"
    echo "DEPENDENCIES="\"$DEPENDENCIES\""" >> "$CONFDIR"/"$SAVEDIR"
}

targithubinfofunc () { # Gets updated_at, tar url, and description for specified package for use with listing, installing, and upgrading
    if [ -z "$GITHUB_TOKEN" ]; then
        wget --quiet "$TAR_API_URI" -O "$CONFDIR"/cache/"$TARPKG"-release || { ssft_display_error "${CLR_RED}Error" "wget $TAR_API_URI failed; has the repo been renamed or deleted?${CLR_CLEAR}"; rm -rf "$CONFDIR"/cache/*; exit 1; }
    else
        wget --quiet --auth-no-challenge --header="Authorization: token "$GITHUB_TOKEN"" "$TAR_API_URI" -O "$CONFDIR"/cache/"$TARPKG"-release || { ssft_display_error "${CLR_RED}Error" "wget $TAR_API_URI failed; is your token valid?${CLR_CLEAR}"; rm -rf "$CONFDIR"/cache/*; exit 1; }
    fi
    JQARG=".[].assets[] | select(.name | contains(\".tar\")) | select(.name | contains(\"$TARPKG_NAME\")) | select(.name | contains(\"darwin\") | not) | select(.name | contains(\"macos\") | not) | select(.name | contains(\"ia32\") | not) | select(.name | contains(\"x32\") | not) | select(.name | contains(\"i386\") | not) | select(.name | contains(\"i686\") | not) | { name: .name, updated: .updated_at, url: .browser_download_url, size: .size, numdls: .download_count}"
    cat "$CONFDIR"/cache/"$TARPKG"-release | "$RUNNING_DIR"/jq --raw-output "$JQARG" | sed 's%{%data:%g' | tr -d '",}' > "$CONFDIR"/cache/"$TARPKG"release
    if [ "$(cat "$CONFDIR"/cache/"$TARPKG"release | wc -l)" = "0" ]; then
        rm "$CONFDIR"/cache/"$TARPKG"release
        JQARG=".[].assets[] | select(.name | contains(\".tar\")) | select(.name | contains(\"macos\") | not) | select(.name | contains(\"darwin\") | not) | select(.name | contains(\"ia32\") | not) | select(.name | contains(\"x32\") | not) | select(.name | contains(\"i386\") | not) | select(.name | contains(\"i686\") | not) | { name: .name, updated: .updated_at, url: .browser_download_url, size: .size, numdls: .download_count}"
        cat "$CONFDIR"/cache/"$TARPKG"-release | "$RUNNING_DIR"/jq --raw-output "$JQARG" | sed 's%{%data:%g' | tr -d '",}' > "$CONFDIR"/cache/"$TARPKG"release
    fi
    NEW_TARFILE="$(cat "$CONFDIR"/cache/"$TARPKG"release | "$RUNNING_DIR"/yaml r - data.name)"
    TAR_GITHUB_NEW_COMMIT="$(cat "$CONFDIR"/cache/"$TARPKG"release | "$RUNNING_DIR"/yaml r - data.updated)"
    TAR_NEW_VERSION="$TAR_GITHUB_NEW_COMMIT"
    TAR_GITHUB_NEW_DOWNLOAD="$(cat "$CONFDIR"/cache/"$TARPKG"release | "$RUNNING_DIR"/yaml r - data.url)"
    TAR_SIZE="$(cat "$CONFDIR"/cache/"$TARPKG"release | "$RUNNING_DIR"/yaml r - data.size)"
    TAR_SIZE="$(awk "BEGIN {print ("$TAR_SIZE"/1024)/1024}" | cut -c-5) MBs"
    TAR_DOWNLOADS="$(cat "$CONFDIR"/cache/"$TARPKG"release | "$RUNNING_DIR"/yaml r - data.numdls)"
    TAR_DOWNLOAD_SOURCE="GITHUB"
    # TAR_GITHUB_NEW_VERSION="$(echo "$TAR_GITHUB_NEW_DOWNLOAD" | cut -f8 -d"/")"
    TARURI="$(echo "$TARURI" | cut -f-5 -d'/')"
    TAR_GITHUB_NEW_VERSION="$(echo "$TAR_GITHUB_NEW_DOWNLOAD" | cut -f8 -d'/')"
    tarsaveconffunc "cache/$TARPKG.conf"
    . "$CONFDIR"/cache/"$TARPKG".conf
    if [ -z "$NEW_TARFILE" ]; then
        ssft_display_error "${CLR_RED}Error" "Error finding latest tar for $TARPKG!${CLR_CLEAR}"
        GITHUB_DOWNLOAD_ERROR="TRUE"
    fi
}

tarappcheckfunc () { # check user input against list of known apps here
    case $("$RUNNING_DIR"/yaml r "$CONFDIR"/tar-pkgs.yml "$TARPKG") in
        null)
            KNOWN_TAR="FALSE"
            ;;
        *)
            KNOWN_TAR="TRUE"
            ;;
    esac
    case $KNOWN_TAR in
        TRUE)
            if [ ! -z "$DOWNLOAD_SOURCE" ]; then
                TAR_DOWNLOAD_SOURCE="$DOWNLOAD_SOURCE"
            fi
            SPM_TAR_REPO_BRANCH="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tar-pkgs.yml "$TARPKG")"
            case $SPM_TAR_REPO_BRANCH in
                tar-github)
                    TAR_CLR="${CLR_LCYAN}"
                    TAR_DOWNLOAD_SOURCE="GITHUB"
                    if [ ! -f "$CONFDIR/tarinstalled/.$TARPKG.yml" ]; then
                        wget --quiet "https://github.com/simoniz0r/spm-repo/raw/tar-github/$TARPKG.yml" -O "$CONFDIR"/tarinstalled/."$TARPKG".yml
                    fi
                    ;;
                tar-other)
                    TAR_CLR="${CLR_CYAN}"
                    TAR_DOWNLOAD_SOURCE="DIRECT"
                    if [ ! -f "$CONFDIR/tarinstalled/.$TARPKG.yml" ]; then
                        wget --quiet "https://github.com/simoniz0r/spm-repo/raw/tar-other/$TARPKG.yml" -O "$CONFDIR"/tarinstalled/."$TARPKG".yml
                    fi
                    ;;
            esac
            TARPKG_NAME="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml name)"
            INSTDIR="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml instdir)"
            TARURI="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml taruri)"
            if [ "$TAR_DOWNLOAD_SOURCE" = "GITHUB" ]; then
                TAR_API_URI="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml apiuri)"
            fi
            DESKTOP_FILE_PATH="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml desktop_file_path)"
            ICON_FILE_PATH="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml icon_file_path)"
            EXECUTABLE_FILE_PATH="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml executable_file_path)"
            BIN_PATH="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml bin_path)"
            # CONFIG_PATH="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml config_path)"
            TAR_DESCRIPTION="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml description)"
            DEPENDENCIES="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tarinstalled/."$TARPKG".yml dependencies)"
            if [ "$TAR_DOWNLOAD_SOURCE" = "GITHUB" ]; then
                targithubinfofunc
            else
                TAR_SIZE="N/A"
                TAR_DOWNLOADS="N/A"
                NEW_TARURI="$(wget -S --read-timeout=30 --spider "$TARURI" 2>&1 | grep -m 1 'Location:' | cut -f4 -d' ')"
                case $NEW_TARURI in
                    http*)
                        NEW_TARFILE="${NEW_TARURI##*/}"
                        ;;
                    *)
                        NEW_TARFILE="${TARURI##*/}"
                        ;;
                esac
                TAR_NEW_VERSION="$NEW_TARFILE"
                tarsaveconffunc "cache/$TARPKG.conf"
            fi
            ;;
    esac
}

tarlistfunc () { # List info about specified package or list all packages
    if [ -f "$CONFDIR"/tarinstalled/"$TARPKG" ]; then
        . "$CONFDIR"/tarinstalled/"$TARPKG"
        if [ ! -z "$DOWNLOAD_SOURCE" ]; then
            TAR_DOWNLOAD_SOURCE="$DOWNLOAD_SOURCE"
        fi
        if [ "$TAR_DOWNLOAD_SOURCE" = "GITHUB" ]; then
            TAR_CLR="${CLR_LCYAN}"
        else
            TAR_CLR="${CLR_CYAN}"
        fi
        echo "${TAR_CLR}$TARPKG tar installed information${CLR_CLEAR}:"
        echo "${TAR_CLR}Info${CLR_CLEAR}:  $TAR_DESCRIPTION"
        echo "${TAR_CLR}Deps${CLR_CLEAR}:  $DEPENDENCIES"
        if [ -z "$TAR_GITHUB_COMMIT" ]; then
            echo "${TAR_CLR}Version${CLR_CLEAR}:  $TARFILE"
        else
            echo "${TAR_CLR}Version${CLR_CLEAR}:  $TAR_GITHUB_COMMIT"
            echo "${TAR_CLR}Tag${CLR_CLEAR}:  $TAR_GITHUB_VERSION"
            echo "${TAR_CLR}Total DLs${CLR_CLEAR}:  $TAR_DOWNLOADS"
            echo "${TAR_CLR}Size${CLR_CLEAR}:  $TAR_SIZE"
        fi
        echo "${TAR_CLR}URL${CLR_CLEAR}:  $TARURI"
        echo "${TAR_CLR}Install dir${CLR_CLEAR}:  $INSTDIR"
        echo "${TAR_CLR}Bin path${CLR_CLEAR}:  $BIN_PATH"
        echo
    else
        if [ -f "$CONFDIR/cache/$TARPKG.yml" ]; then
            rm -f "$CONFDIR"/cache/"$TARPKG".yml
        fi
        tarappcheckfunc "$TARPKG"
        if [ "$KNOWN_TAR" = "TRUE" ]; then
            echo "${TAR_CLR}$TARPKG tar package information${CLR_CLEAR}:"
            tarsaveconffunc "cache/$TARPKG.conf"
            . "$CONFDIR"/cache/"$TARPKG".conf
            echo "${TAR_CLR}Info${CLR_CLEAR}:  $TAR_DESCRIPTION"
            echo "${TAR_CLR}Deps${CLR_CLEAR}:  $DEPENDENCIES"
            if [ -z "$TAR_GITHUB_COMMIT" ]; then
                echo "${TAR_CLR}Version${CLR_CLEAR}:  $TARFILE"
            else
                echo "${TAR_CLR}Version${CLR_CLEAR}:  $TAR_GITHUB_COMMIT"
                echo "${TAR_CLR}Tag${CLR_CLEAR}:  $TAR_GITHUB_VERSION"
                echo "${TAR_CLR}Total DLs${CLR_CLEAR}:  $TAR_DOWNLOADS"
                echo "${TAR_CLR}Size${CLR_CLEAR}:  $TAR_SIZE"
            fi
            echo "${TAR_CLR}URL${CLR_CLEAR}:  $TARURI"
            echo "${TAR_CLR}Install dir${CLR_CLEAR}:  $INSTDIR"
            echo "${TAR_CLR}Bin path${CLR_CLEAR}:  $BIN_PATH"
            echo
            rm -f "$CONFDIR"/tarinstalled/."$TARPKG".yml
        else
            TARPKG_NOT_FOUND="TRUE"
        fi
    fi
}

tarlistinstalledfunc () { # List info about installed tar packages
    for tarpkg in $(dir -C -w 1 "$CONFDIR"/tarinstalled); do
        . "$CONFDIR"/tarinstalled/"$tarpkg"
        if [ ! -z "$DOWNLOAD_SOURCE" ]; then
            TAR_DOWNLOAD_SOURCE="$DOWNLOAD_SOURCE"
        fi
        if [ "$TAR_DOWNLOAD_SOURCE" = "GITHUB" ]; then
            TAR_CLR="${CLR_LCYAN}"
        else
            TAR_CLR="${CLR_CYAN}"
        fi
        echo "${TAR_CLR}$tarpkg installed information${CLR_CLEAR}:"
        echo "${TAR_CLR}Info${CLR_CLEAR}:  $TAR_DESCRIPTION"
        echo "${TAR_CLR}Deps${CLR_CLEAR}:  $DEPENDENCIES"
        if [ "$TAR_DOWNLOAD_SOURCE" = "DIRECT" ]; then
            TAR_SIZE="N/A"
            TAR_DOWNLOADS="N/A"
            echo "${TAR_CLR}Version${CLR_CLEAR}:  $TARFILE"
        else
            echo "${TAR_CLR}Version${CLR_CLEAR}:  $TAR_GITHUB_COMMIT"
            echo "${TAR_CLR}Tag${CLR_CLEAR}:  $TAR_GITHUB_VERSION"
            echo "${TAR_CLR}Total DLs${CLR_CLEAR}:  $TAR_DOWNLOADS"
            echo "${TAR_CLR}Size${CLR_CLEAR}:  $TAR_SIZE"
        fi
        echo "${TAR_CLR}URL${CLR_CLEAR}:  $TARURI"
        echo "${TAR_CLR}Install dir${CLR_CLEAR}:  $INSTDIR"
        echo "${TAR_CLR}Bin path${CLR_CLEAR}:  $BIN_PATH"
        echo
    done
}

tardlfunc () { # Download tar from specified source.  If not from github, use --trust-server-names to make sure the tar file is saved with the proper file name
    cd "$CONFDIR"/cache
    case $TAR_DOWNLOAD_SOURCE in
        GITHUB)
            wget --read-timeout=30 "$TAR_GITHUB_NEW_DOWNLOAD" || { ssft_display_error "${CLR_RED}Error" "wget $TARURI_DL failed; exiting...${CLR_CLEAR}"; rm -rf "$CONFDIR"/cache/*; exit 1; }
            ;;
        DIRECT)
            wget --read-timeout=30 --trust-server-names "$TARURI" || { ssft_display_error "${CLR_RED}Error" "wget $TARURI failed; exiting...${CLR_CLEAR}"; rm -rf "$CONFDIR"/cache/*; exit 1; }
            ;;
    esac
    TARFILE="$(dir "$CONFDIR"/cache/*.tar*)"
    TARFILE="${TARFILE##*/}"
    NEW_TARFILE="$TARFILE"
}

tarcheckfunc () { # Check to make sure downloaded file is a tar and run relevant tar arguments for type of tar
    mkdir "$CONFDIR"/cache/pkg
    case $TARFILE in
        *tar.gz|*tar.bz2|*tar.tbz|*tar.tb2|*tar|*tar.xz)
            tar -xvf "$CONFDIR"/cache/"$TARFILE" -C "$CONFDIR"/cache/pkg || { ssft_display_error "${CLR_RED}Error" "tar $TARFILE failed; exiting...${CLR_CLEAR}"; rm -rf "$CONFDIR"/cache/*; exit 1; }
            ;;
        *)
            ssft_display_error "${CLR_RED}Error" "Unknown file type!${CLR_CLEAR}"
            rm -rf "$CONFDIR"/cache/*
            exit 1
            ;;
    esac
}

checktarversionfunc () { # Use info from githubinfo function or using wget -S --spider for redirecting links
    . "$CONFDIR"/tarinstalled/"$TARPKG"
    if [ "$TAR_DOWNLOAD_SOURCE" = "GITHUB" ]; then
        if [ "$GITHUB_DOWNLOAD_ERROR" = "TRUE" ]; then
            TAR_NEW_UPGRADE="FALSE"
            GITHUB_DOWNLOAD_ERROR="FALSE"
        elif [ "$TAR_FORCE_UPGRADE" = "TRUE" ]; then
            TAR_NEW_UPGRADE="TRUE"
            TAR_FORCE_UPGRADE="FALSE"
        elif [ $TAR_GITHUB_COMMIT != $TAR_GITHUB_NEW_COMMIT ]; then
            TAR_NEW_UPGRADE="TRUE"
        else
            TAR_NEW_UPGRADE="FALSE"
        fi
    else
        if [ "$TAR_FORCE_UPGRADE" = "TRUE" ]; then
            TAR_NEW_UPGRADE="TRUE"
            TAR_FORCE_UPGRADE="FALSE"
        elif [ -z "$NEW_TARFILE" ]; then
            TAR_NEW_UPGRADE="FALSE"
        elif [[ "$NEW_TARFILE" != "$TARFILE" ]]; then
            TAR_NEW_UPGRADE="TRUE"
        elif [ "$RENAMED" = "TRUE" ] && [ -d /opt/"$OLD_NAME" ]; then
            TAR_NEW_UPGRADE="TRUE"
        else
            TAR_NEW_UPGRADE="FALSE"
        fi
    fi
    if [ -z "$NEW_TARFILE" ] && [ -z "$NEW_COMMIT" ] && [ "$TAR_FORCE_UPGRADE" = "FALSE" ]; then
        ssft_display_error "${CLR_RED}Error" "Error checking new version for $TARPKG!${CLR_CLEAR}"
        TAR_NEW_UPGRADE="FALSE"
    fi
}

tarupdateforcefunc () { # Mark specified tar package for upgrade without checking version
    if [ -f "$CONFDIR"/tarinstalled/"$TARPKG" ]; then
        . "$CONFDIR"/tarinstalled/"$TARPKG"
        if [ ! -z "$DOWNLOAD_SOURCE" ]; then
            TAR_DOWNLOAD_SOURCE="$DOWNLOAD_SOURCE"
        fi
        if [ "$TAR_DOWNLOAD_SOURCE" = "GITHUB" ]; then
            TAR_CLR="${CLR_LCYAN}"
        else
            TAR_CLR="${CLR_CYAN}"
        fi
        echo "${TAR_CLR}Info${CLR_CLEAR}:  $TAR_DESCRIPTION"
        echo "${TAR_CLR}Deps${CLR_CLEAR}:  $DEPENDENCIES"
        if [ -z "$TAR_GITHUB_COMMIT" ]; then
            echo "${TAR_CLR}Version${CLR_CLEAR}:  $TARFILE"
        else
            echo "${TAR_CLR}Version${CLR_CLEAR}:  $TAR_GITHUB_COMMIT"
            echo "${TAR_CLR}Tag${CLR_CLEAR}:  $TAR_GITHUB_VERSION"
            echo "${TAR_CLR}Total DLs${CLR_CLEAR}:  $TAR_DOWNLOADS"
            echo "${TAR_CLR}Size${CLR_CLEAR}:  $TAR_SIZE"

        fi
        echo "${TAR_CLR}URL${CLR_CLEAR}:  $TARURI"
        echo "${TAR_CLR}Install dir${CLR_CLEAR}:  $INSTDIR"
        echo "${TAR_CLR}Bin path${CLR_CLEAR}:  $BIN_PATH"
        echo
    else
        ssft_display_error "${CLR_RED}Error" "Package not found!${CLR_CLEAR}"
        rm -rf "$CONFDIR"/cache/*
        exit 1
    fi    
    NEW_TARFILE="$TARFILE"
    TAR_GITHUB_NEW_COMMIT="$TAR_GITHUB_COMMIT"
    TAR_GITHUB_NEW_DOWNLOAD="$TAR_GITHUB_DOWNLOAD"
    TAR_GITHUB_NEW_VERSION="$TAR_GITHUB_VERSION"
    echo "Marking ${TAR_CLR}$TARPKG${CLR_CLEAR} for upgrade by force..."
    echo "${TAR_CLR}New upgrade available for $TARPKG!${CLR_CLEAR}"
    tarsaveconffunc "tarupgrades/$TARPKG"
}

tarupgradecheckallfunc () { # Run a for loop to check all installed tar packages for upgrades
    for package in $(dir -C -w 1 "$CONFDIR"/tarinstalled); do
        TARPKG="$package"
        tarappcheckfunc "$package"
        # echo "Checking ${TAR_CLR}$package${CLR_CLEAR} version..."
        checktarversionfunc
        if [ "$TAR_NEW_UPGRADE" = "TRUE" ]; then
            echo "${TAR_CLR}$(tput bold)New upgrade available for $package -- $TAR_NEW_VERSION !${CLR_CLEAR}"
            tarsaveconffunc "tarupgrades/$package"
        fi
    done
}

tarupgradecheckfunc () { # Check specified tar package for upgrade
    case $("$RUNNING_DIR"/yaml r "$CONFDIR"/tar-pkgs.yml "$TARPKG") in
        null)
            ssft_display_error "${CLR_RED}Error" "$1 is not in tar-pkgs.yml; try running 'spm update'.${CLR_CLEAR}"
            ;;
        *)
            echo "Downloading tar-pkgs.yml from spm github repo..."
            rm "$CONFDIR"/tar-pkgs.*
            wget --no-verbose "https://raw.githubusercontent.com/simoniz0r/spm-repo/master/tar-pkgs.yml" -O "$CONFDIR"/tar-pkgs.yml
            TARPKG="$1"
            tarappcheckfunc "$TARPKG"
            echo "Checking ${TAR_CLR}$TARPKG${CLR_CLEAR} version..."
            checktarversionfunc
            if [ "$TAR_NEW_UPGRADE" = "TRUE" ]; then
                echo "${TAR_CLR}New upgrade available for $TARPKG -- $NEW_TARFILE !${CLR_CLEAR}"
                tarsaveconffunc "tarupgrades/$TARPKG"
            else
                echo "No new upgrade for ${TAR_CLR}$TARPKG${CLR_CLEAR}"
            fi
            ;;
    esac
}

tarupdatelistfunc () { # Download tar-pkgs.yml from github repo and run relevant upgradecheck function based on input
    if [ -z "$1" ]; then
        touch "$CONFDIR"/cache/tarupdate.lock
        if [ "$(dir -C -w 1 "$CONFDIR"/tarinstalled | wc -l)" = "0" ]; then
            sleep 0
        else
            if [ "$SPM_REPO_SHA" = "$NEW_SPM_REPO_SHA" ]; then
                sleep 0
            else
                touch "$CONFDIR"/cache/tarupdate.lock
                echo "Downloading tar-pkgs.yml from spm github repo..."
                rm "$CONFDIR"/tar-pkgs.*
                wget --quiet "https://raw.githubusercontent.com/simoniz0r/spm-repo/master/tar-pkgs.yml" -O "$CONFDIR"/tar-pkgs.yml
                echo "tar-pkgs.yml updated!"
                for tarpkg in $(dir -C -w 1 "$CONFDIR"/tarinstalled); do
                    SPM_TAR_REPO_BRANCH="$("$RUNNING_DIR"/yaml r "$CONFDIR"/tar-pkgs.yml $tarpkg)"
                    echo "https://github.com/simoniz0r/spm-repo/raw/$SPM_TAR_REPO_BRANCH/$tarpkg.yml" >> "$CONFDIR"/cache/tar-yml-wget.list
                done
                mkdir "$CONFDIR"/cache/tar
                cd "$CONFDIR"/cache/tar
                wget --quiet -i "$CONFDIR"/cache/tar-yml-wget.list || { ssft_display_error "${CLR_RED}Error" "wget failed!${CLR_CLEAR}"; rm -rf "$CONFDIR"/cache/*; exit 1; }
                echo "tar package info updated!"
                for ymlfile in $(dir -C -w 1 "$CONFDIR"/cache/tar/*.yml); do
                    ymlfile="${ymlfile##*/}"
                    mv "$CONFDIR"/cache/tar/"$ymlfile" "$CONFDIR"/tarinstalled/."$ymlfile"
                done
            fi
            tarupgradecheckallfunc
        fi
        rm -f "$CONFDIR"/cache/tarupdate.lock
    else
        tarupgradecheckfunc "$1"
    fi
}

tardesktopfilefunc () { # Download .desktop files for tar packages that do not include them from spm's github repo
    echo "Downloading $TARPKG.desktop from spm github repo..."
    wget --quiet "https://raw.githubusercontent.com/simoniz0r/spm/master/apps/$TARPKG/$TARPKG.desktop" -O "$CONFDIR"/cache/"$TARPKG".desktop  || { echo "wget $TARURI failed; exiting..."; rm -rf "$CONFDIR"/cache/*; exit 1; }
    echo "Moving $TARPKG.desktop to $INSTDIR ..."
    sudo mv "$CONFDIR"/cache/"$TARPKG".desktop "$INSTDIR"/"$TARPKG".desktop
    DESKTOP_FILE_PATH="$INSTDIR/$TARPKG.desktop"
    DESKTOP_FILE_NAME="$TARPKG.desktop"
}

tarinstallfunc () { # Move extracted tar from $CONFDIR/cache to /opt/PackageName, create symlinks for .desktop and bin files, and save config file for spm to keep track of it
    echo "Moving files to $INSTDIR..."
    for file in $(ls "$CONFDIR/cache/pkg/"); do
        if [ -f "$CONFDIR/cache/pkg/$file" ]; then
            MOVE_CACHE_FILES="TRUE"
        fi
    done
    if [ "$MOVE_CACHE_FILES" = "TRUE" ]; then
        mkdir "$CONFDIR"/cache/temp
        mv "$CONFDIR"/cache/pkg/* "$CONFDIR"/cache/temp/
        mkdir "$CONFDIR"/cache/pkg/"$TARPKG"
        mv "$CONFDIR"/cache/temp/* "$CONFDIR"/cache/pkg/"$TARPKG"/
        rm -rf "$CONFDIR"/cache/temp
    fi
    EXTRACTED_DIR_NAME="$(ls -d "$CONFDIR"/cache/pkg/*/)"
    sudo mv "$EXTRACTED_DIR_NAME" "$INSTDIR" || { echo "Failed!"; rm -rf "$CONFDIR"/cache/*; exit 1; }
    DESKTOP_FILE_NAME="$(basename "$DESKTOP_FILE_PATH")"
    ICON_FILE_NAME="$(basename "$ICON_FILE_PATH")"
    EXECUTABLE_FILE_NAME="$(basename "$EXECUTABLE_FILE_PATH")"
    echo "Creating symlink for $EXECUTABLE_FILE_PATH to /usr/local/bin/$TARPKG ..."
    sudo ln -s "$EXECUTABLE_FILE_PATH" /usr/local/bin/"$TARPKG"
    echo "Creating symlink for $TARPKG.desktop to /usr/share/applications/ ..."
    case $DESKTOP_FILE_PATH in
        DOWNLOAD)
            tardesktopfilefunc "$TARPKG"
            sudo ln -s "$DESKTOP_FILE_PATH" /usr/share/applications/"$DESKTOP_FILE_NAME"
            ;;
        *NONE*)
            echo "Skipping .desktop file..."
            ;;
        *)
            sudo sed -i "s:Exec=.*:Exec="$EXECUTABLE_FILE_PATH":g" "$DESKTOP_FILE_PATH"
            sudo sed -i "s:Icon=.*:Icon="$ICON_FILE_PATH":g" "$DESKTOP_FILE_PATH"
            sudo ln -s "$DESKTOP_FILE_PATH" /usr/share/applications/"$DESKTOP_FILE_NAME"
            ;;
    esac
    echo "Creating config file for ${TAR_CLR}$TARPKG${CLR_CLEAR}..."
    tarsaveconffunc "tarinstalled/$TARPKG"
    echo "${TAR_CLR}$TARPKG${CLR_CLEAR} has been installed to $INSTDIR !"
}

tarinstallstartfunc () { # Check to make sure another command by the same name is not on the system, tar package is in tar-pkgs.list, and tar package is not already installed
    if [ -f "$CONFDIR"/tarinstalled/"$TARPKG" ] || [ -f "$CONFDIR"/appimginstalled/"$TARPKG" ]; then # Exit if already installed by spm
        ssft_display_error "${CLR_RED}Error" "$TARPKG is already installed. Use 'spm upgrade' to install the latest version of $TARPKG.${CLR_CLEAR}"
        rm -rf "$CONFDIR"/cache/*
        exit 1
    fi
    if type >/dev/null 2>&1 "$TARPKG"; then
        ssft_display_error "${CLR_RED}Error" "$TARPKG is already installed and not managed by spm; exiting...${CLR_CLEAR}"
        rm -rf "$CONFDIR"/cache/*
        exit 1
    fi
    if [ -d "/opt/$TARPKG" ]; then
        ssft_display_error "${CLR_RED}Error" "/opt/$TARPKG exists; spm cannot install to existing directories!${CLR_CLEAR}"
        rm -rf "$CONFDIR"/cache/*
        exit 1
    fi
    tarappcheckfunc "$TARPKG"
    if [ "$KNOWN_TAR" = "FALSE" ];then
        ssft_display_error "${CLR_RED}Error" "$TARPKG is not in tar-pkgs.yml; try running 'spm update' to update tar-pkgs.yml${CLR_CLEAR}."
        rm -rf "$CONFDIR"/cache/*
        exit 1
    else
        ssft_select_single "${TAR_CLR}$TARPKG${CLR_CLEAR} tar package: $TARFILE" "$TARPKG will be installed. Continue?" "Install $TARPKG" "Exit"
        case $SSFT_RESULT in
            Exit|N*|n*)
                ssft_display_error "${CLR_RED}Error" "$TARPKG was not installed.${CLR_CLEAR}"
                rm -f "$CONFDIR"/tarinstalled/."$TARPNG".yml
                rm -rf "$CONFDIR"/cache/*
                exit 0
                ;;
        esac
    fi
}

tarupgradefunc () { # Move new extracted tar from $CONFDIR/cache to /opt/PackageName and save new config file for it
    echo
    ssft_select_single "Would you like to do a clean upgrade (remove all files in /opt/$TARPKG before installing) or an overwrite upgrade?" "Note: If you are using Discord with client modifications, it is recommended that you do a clean upgrade. Choice?" "Clean" "Overwrite"
    case $SSFT_RESULT in
        Clean|clean)
            echo "${TAR_CLR}$TARPKG${CLR_CLEAR} will be upgraded to $TARFILE."
            echo "Removing files in $INSTDIR..."
            sudo rm -rf "$INSTDIR" || { echo "Failed!"; rm -rf "$CONFDIR"/cache/*; exit 1; }
            echo "Moving files to $INSTDIR..."
            EXTRACTED_DIR_NAME="$(ls -d "$CONFDIR"/cache/pkg/*/)"
            sudo mv "$EXTRACTED_DIR_NAME" "$INSTDIR"
            ;;
        Overwrite|overwrite)
            echo "${TAR_CLR}$TARPKG${CLR_CLEAR} will be upgraded to $TARFILE."
            echo "Copying files to $INSTDIR..."
            EXTRACTED_DIR_NAME="$(ls -d "$CONFDIR"/cache/pkg/*/)"
            sudo cp -r "$EXTRACTED_DIR_NAME"/* "$INSTDIR"/ || { echo "Failed!"; rm -rf "$CONFDIR"/cache/*; exit 1; }
            ;;
        *)
            ssft_display_error "${CLR_RED}Error" "Invalid choice; ${CLR_RED}$TARPKG was not upgraded.${CLR_CLEAR}"
            rm -rf "$CONFDIR"/cache/*
            exit 1
            ;;
    esac
    case $DESKTOP_FILE_PATH in
        DOWNLOAD)
            tardesktopfilefunc "$TARPKG"
            sudo ln -sf "$DESKTOP_FILE_PATH" /usr/share/applications/"$DESKTOP_FILE_NAME"
            ;;
        *NONE*)
            echo "Skipping .desktop file..."
            ;;
        *)
            sudo sed -i "s:Exec=.*:Exec="$EXECUTABLE_FILE_PATH":g" "$DESKTOP_FILE_PATH"
            sudo sed -i "s:Icon=.*:Icon="$ICON_FILE_PATH":g" "$DESKTOP_FILE_PATH"
            sudo ln -sf "$DESKTOP_FILE_PATH" /usr/share/applications/"$DESKTOP_FILE_NAME"
            ;;
    esac
    echo "Creating config file for ${TAR_CLR}$TARPKG${CLR_CLEAR}..."
    tarsaveconffunc "tarinstalled/$TARPKG"
    echo "${TAR_CLR}$TARPKG${CLR_CLEAR} has been upgraded to version $TARFILE!"
}

tarupgradestartallfunc () { # Run upgrades on all available tar packages
    if [ "$TARUPGRADES" = "FALSE" ]; then
        sleep 0
    else
        if [ "$(dir "$CONFDIR"/tarupgrades | wc -l)" = "1" ]; then
            echo "${TAR_CLR}$(dir -C -w 1 "$CONFDIR"/tarupgrades | wc -l) new tar package upgrade available.${CLR_CLEAR}"
        else
            echo "${TAR_CLR}$(dir -C -w 1 "$CONFDIR"/tarupgrades | wc -l) new tar package upgrades available.${CLR_CLEAR}"
        fi
        dir -C -w 1 "$CONFDIR"/tarupgrades | pr -tT --column=3 -w 125
        echo
        ssft_select_single "               " "Start upgrade?" "Start upgrade" "Exit"
        case $SSFT_RESULT in
            Start*|Y*|y*)
                for UPGRADE_PKG in $(dir -C -w 1 "$CONFDIR"/tarupgrades); do
                    TARPKG="$UPGRADE_PKG"
                    echo "Downloading ${TAR_CLR}$TARPKG${CLR_CLEAR}..."
                    tarappcheckfunc "$TARPKG"
                    if [ "$TAR_DOWNLOAD_SOURCE" = "GITHUB" ]; then
                        targithubinfofunc
                    fi
                    tardlfunc "$TARPKG"
                    tarcheckfunc
                    tarupgradefunc
                    rm "$CONFDIR"/tarupgrades/"$TARPKG"
                    rm -rf "$CONFDIR"/cache/*
                    echo
                done
                ;;
            Exit|N*|n*)
                ssft_display_error "${CLR_RED}Error" "No packages were upgraded; exiting...${CLR_CLEAR}"
                rm -rf "$CONFDIR"/cache/*
                exit 0
                ;;
        esac
    fi
}

tarupgradestartfunc () { # Run upgrade on specified tar package
    ssft_select_single "${TAR_CLR}$TARPKG${CLR_CLEAR} upgrade" "$TARPKG will be upgraded to the latest version. Continue?" "Upgrade $TARPKG" "Exit"
    case $SSFT_RESULT in
        Upgrade*|Y*|y*)
            tarappcheckfunc "$TARPKG"
            if [ "$TAR_DOWNLOAD_SOURCE" = "GITHUB" ]; then
                targithubinfofunc
            fi
            tardlfunc "$TARPKG"
            tarcheckfunc
            tarupgradefunc
            rm "$CONFDIR"/tarupgrades/"$TARPKG"
            ;;
        Exit|N*|n*)
            ssft_display_error "${CLR_RED}Error" "$TARPKG was not upgraded.${CLR_CLEAR}"
            ;;
    esac
}

tarremovefunc () { # Remove tar package, .desktop and bin files, and remove config file spm used to keep track of it
    . "$CONFDIR"/tarinstalled/"$REMPKG"
    ssft_select_single "Removing ${TAR_CLR}$REMPKG${CLR_CLEAR}..." "All files in $INSTDIR will be removed! Continue?" "Remove $REMPKG" "Exit"
    case $SSFT_RESULT in
        Exit|N*|n*)
            ssft_display_error "${CLR_RED}Error" "$REMPKG was not removed.${CLR_CLEAR}"
            rm -rf "$CONFDIR"/cache/*
            exit 0
            ;;
    esac
    if [ -f "$CONFDIR"/tarupgrades/$REMPKG ]; then
        rm "$CONFDIR"/tarupgrades/"$REMPKG"
    fi
    DESKTOP_FILE_NAME="$(basename "$DESKTOP_FILE_PATH")"
    ICON_FILE_NAME="$(basename "$ICON_FILE_PATH")"
    EXECUTABLE_FILE_NAME="$(basename "$EXECUTABLE_FILE_PATH")"
    echo "Removing $INSTDIR..."
    sudo rm -rf "$INSTDIR" || { echo "Failed!"; rm -rf "$CONFDIR"/cache/*; exit 1; }
    echo "Removing symlinks..."
    case $DESKTOP_FILE_PATH in
        NONE)
            echo "Skipping .desktop file..."
            ;;
        *)
            sudo rm /usr/share/applications/"$DESKTOP_FILE_NAME"
            ;;
    esac
    sudo rm /usr/local/bin/"$REMPKG"
    rm "$CONFDIR"/tarinstalled/"$REMPKG"
    rm "$CONFDIR"/tarinstalled/."$REMPKG".yml
    echo "${TAR_CLR}$REMPKG${CLR_CLEAR} has been removed!"
}

tarremovepurgefunc () { # Remove tar package, .desktop and bin files, package's config dir if listed in tar-pkgs.yml, and remove config file spm used to keep track of it
    . "$CONFDIR"/tarinstalled/"$PURGEPKG"
    ssft_select_single "Removing ${TAR_CLR}$PURGEPKG${CLR_CLEAR}..." "All files in $INSTDIR and $CONFIG_PATH will be removed! Continue?" "Remove $PURGEPKG" "Exit"
    case $SSFT_RESULT in
        Exit|N*|n*)
            ssft_display_error "${CLR_RED}Error" "$PURGE was not removed.${CLR_CLEAR}"
            rm -rf "$CONFDIR"/cache/*
            exit 0
            ;;
    esac
    if [ -f "$CONFDIR"/tarupgrades/$PURGEPKG ]; then
        rm "$CONFDIR"/tarupgrades/"$PURGEPKG"
    fi
    DESKTOP_FILE_NAME="$(basename "$DESKTOP_FILE_PATH")"
    ICON_FILE_NAME="$(basename "$ICON_FILE_PATH")"
    EXECUTABLE_FILE_NAME="$(basename "$EXECUTABLE_FILE_PATH")"
    echo "Removing $INSTDIR..."
    sudo rm -rf "$INSTDIR" || { echo "Failed!"; rm -rf "$CONFDIR"/cache/*; exit 1; }
    echo "Removing symlinks..."
    case $DESKTOP_FILE_PATH in
        NONE)
            echo "Skipping .desktop file..."
            ;;
        *)
            sudo rm /usr/share/applications/"$DESKTOP_FILE_NAME"
            ;;
    esac
    sudo rm /usr/local/bin/"$PURGEPKG"
    echo "Removing $CONFIG_PATH..."
    if [ ! -z "$CONFIG_PATH" ]; then
        rm -rf "$CONFIG_PATH"
    else
        echo "No config path specified; skipping..."
    fi
    rm "$CONFDIR"/tarinstalled/"$PURGEPKG"
    echo "${TAR_CLR}$PURGEPKG${CLR_CLEAR} has been removed!"
}
