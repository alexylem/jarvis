#!/bin/bash
hash 'espeak' 2>/dev/null || {
    dialog_yesno "espeak doesn't seem to be installed.\nDo you want to install it?" true >/dev/null && {
        if [[ "$platform" == "linux" ]]; then
            echo "Updating..."
            sudo apt-get -qq update || exit 1
            echo "Upgrading..."
            sudo apt-get -qq upgrade -y || exit 1
            echo "Downloading & Installing..."
            sudo apt-get install -y espeak >/dev/null || exit 1
        elif [[ "$platform" == "osx" ]]; then
            echo "Downloading & Installing..."
            brew install espeak || exit 1
        else
            dialog_msg "Unknown platform"
            exit 1
        fi
        dialog_msg "Installation Completed"
    }
}

espeak_TTS () { # TTS () {} Speaks text $1
    /usr/bin/espeak -v ${language:0:2} "$1" 2>/dev/null;
}
