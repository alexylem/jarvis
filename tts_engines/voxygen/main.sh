#!/bin/bash
trim() {
    # Determine if 'extglob' is currently on.
    local extglobWasOff=1
    shopt extglob >/dev/null && extglobWasOff=0
    (( extglobWasOff )) && shopt -s extglob # Turn 'extglob' on, if currently turned off.
    # Trim leading and trailing whitespace
    local var=$1
    var=${var##+([[:space:]])}
    var=${var%%+([[:space:]])}
    (( extglobWasOff )) && shopt -u extglob # If 'extglob' was off before, turn it back off.
    echo -n "$var" # Output trimmed string.
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

voxygen_TTS () { # TTS () {} Speaks text $1
    [[ "$platform" == "osx" ]] && md5='md5' || md5='md5sum'
    audio_file="$tmp_folder/`echo -n $1 | $md5 | awk '{print $1}'`.mp3"
    VOXY_URL="https://www.voxygen.fr/sites/all/modules/voxygen_voices/assets/proxy/index.php"
    HEADER=$(curl -sS -G -X HEAD -i $VOXY_URL --data-urlencode "method=redirect" --data-urlencode "text=`rawurlencode \"$1\"`" --data-urlencode "voice=Loic")
    IFS=$'\n'; arrHEAD=($HEADER); unset IFS;
        for i in "${arrHEAD[@]}"
        do
                IFS=$':' ; arrLine=($i); unset IFS;
                S=$(trim "${arrLine[0]}")
                if [ "$S" = "Location" ]; then
                        MP3_URL="https:"$(trim "${arrLine[1]}")
                        #2nd HTTP GET request to download mp3 file
                         [ -f $audio_file ] || curl -sS $MP3_URL > $audio_file
                        break
                fi
        done
        #Playing mp3 file
        mpg123 -q $audio_file
}
