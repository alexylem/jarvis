#!/bin/bash
hash 'pico2wave' 2>/dev/null || {
    dialog_yesno "SVOX Pico doesn't seem to be installed.\nDo you want to install it?" true >/dev/null && {
        if [[ "$platform" == "linux" ]]; then
            echo -e "Updating..."
            sudo apt-get -qq update || exit 1
            echo -e "Upgrading..."
            sudo apt-get -qq upgrade -y || exit 1
            echo -e "Downloading & Installing..."
            sudo apt-get install -y libttspico-utils >/dev/null || exit 1
            dialog_msg "Installation Completed"
        elif [[ "$platform" == "osx" ]]; then
            dialog_msg "SVOX Pico is not available on your platform"
        else
            dialog_msg "Unknown platform"
            exit 1
        fi
    }
}

svox_pico_TTS () { # TTS () {} Speaks text $1
    wavfile="$jv_cache_folder/tts.wav"
    /usr/bin/pico2wave -l ${language//_/-} -w "$wavfile" "$1"
    jv_play "$wavfile"
}
