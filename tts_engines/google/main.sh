#!/bin/bash
hash 'mpg123' 2>/dev/null || {
    dialog_yesno "mpg123 doesn't seem to be installed.\nDo you want to install it?" true >/dev/null && {
        if [[ "$platform" == "linux" ]]; then
            echo "Updating..."
            sudo apt-get -qq update || exit 1
            echo "Upgrading..."
            sudo apt-get -qq upgrade -y || exit 1
            echo "Downloading & Installing..."
            sudo apt-get install -y mpg123 >/dev/null || exit 1
        elif [[ "$platform" == "osx" ]]; then
            echo "Downloading & Installing..."
            brew install mpg123 || exit 1
        else
            dialog_msg "Unknown platform"
            exit 1
        fi
        dialog_msg "Installation Completed"
    }
}

rawurlencode() { # here because used in TTS
  local string="${1}"
  local strlen=${#string}
  local encoded=""

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"
}

google_TTS () { # TTS () {} Speaks text $1
    [[ "$platform" == "osx" ]] && md5='md5' || md5='md5sum'
    audio_file="$tmp_folder/`echo -n $1 | $md5 | awk '{print $1}'`.mp3"
    local lang=${language:0:2}
    [ -f $audio_file ] || wget `$verbose || echo -q` -U Mozilla -O $audio_file "http://translate.google.com/translate_tts?tl=$lang&client=tw-ob&ie=UTF-8&q=`rawurlencode \"$1\"`"
    mpg123 -q ` [ $play_hw = false ] || echo "-a $play_hw"` $audio_file # space between ` and [ is important
}
