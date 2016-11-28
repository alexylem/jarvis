#!/bin/bash
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
    mpg123 -q $audio_file
}
