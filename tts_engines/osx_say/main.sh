#!/bin/bash
hash 'say' 2>/dev/null || {
    dialog_yesno "OSX Say doesn't seem to be installed.\nDo you want to install it?" true >/dev/null && {
        if [[ "$platform" == "linux" ]]; then
            dialog_msg "OSX Say is not available on your platform"
        elif [[ "$platform" == "osx" ]]; then
            dialog_msg "OSX Say should be installed on every Mac"
        else
            dialog_msg "Unknown platform"
            exit 1
        fi
    }
}

[ -z "$osx_say_voice" ] && osx_say_voice=`/usr/bin/say -v ? | grep $language | head -n 1 | awk '{print $1}'`

osx_say_TTS () { # TTS () {} Speaks text $1
    /usr/bin/say -v $osx_say_voice "$1"
}
