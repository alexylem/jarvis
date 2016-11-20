#!/bin/bash
hash 'espeak' 2>/dev/null || {
    dialog_yesno "espeak doesn't seem to be installed.\nDo you want to install it?" true >/dev/null && {
        jv_install espeak || exit 1
        dialog_msg "Installation Completed"
    }
}

espeak_TTS () { # TTS () {} Speaks text $1
    /usr/bin/espeak -v ${language:0:2} "$1" 2>/dev/null;
}
