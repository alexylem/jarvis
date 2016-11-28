#!/bin/bash
# trim() {
#     # Determine if 'extglob' is currently on.
#     local extglobWasOff=1
#     shopt extglob >/dev/null && extglobWasOff=0
#     (( extglobWasOff )) && shopt -s extglob # Turn 'extglob' on, if currently turned off.
#     # Trim leading and trailing whitespace
#     local var=$1
#     var=${var##+([[:space:]])}
#     var=${var%%+([[:space:]])}
#     (( extglobWasOff )) && shopt -u extglob # If 'extglob' was off before, turn it back off.
#     echo -n "$var" # Output trimmed string.
# }
# 
# rawurlencode() { # here because used in TTS
#   local string="${1}"
#   local strlen=${#string}
#   local encoded=""
# 
#   for (( pos=0 ; pos<strlen ; pos++ )); do
#      c=${string:$pos:1}
#      case "$c" in
#         [-_.~a-zA-Z0-9] ) o="${c}" ;;
#         * )               printf -v o '%%%02x' "'$c"
#      esac
#      encoded+="${o}"
#   done
#   echo "${encoded}"
# }
# 
# voxygen_TTS () { # TTS () {} Speaks text $1
#     [[ "$platform" == "osx" ]] && md5='md5' || md5='md5sum'
#     local audio_file="$tmp_folder/`echo -n $1 | $md5 | awk '{print $1}'`.mp3"
#     local VOXY_URL="https://www.voxygen.fr/sites/all/modules/voxygen_voices/assets/proxy/index.php"
#     local HEADER=$(curl -sS -G -X HEAD -i $VOXY_URL --data-urlencode "method=redirect" --data-urlencode "text=`rawurlencode \"$1\"`" --data-urlencode "voice=$voxygen_voice")
#     IFS=$'\n'; arrHEAD=($HEADER); unset IFS;
#         for i in "${arrHEAD[@]}"
#         do
#                 IFS=$':' ; arrLine=($i); unset IFS;
#                 S=$(trim "${arrLine[0]}")
#                 if [ "$S" = "Location" ]; then
#                         MP3_URL="https:"$(trim "${arrLine[1]}")
#                         #2nd HTTP GET request to download mp3 file
#                          [ -f $audio_file ] || curl -sS $MP3_URL > $audio_file
#                         break
#                 fi
#         done
#         #Playing mp3 file
#         mpg123 -q $audio_file
# }

voxygen_TTS () { # Speaks text $1
    local audio_file="/tmp/$(jv_sanitize "$1" _).mp3"
    if [ ! -f "$audio_file" ]; then
        printf "$_gray" # output in verbose mode will be displayed in gray
        wget $($verbose || echo -q) -O "$audio_file" "http://www.voxygen.fr/sites/all/modules/voxygen_voices/assets/proxy/index.php?method=redirect&text=$1&voice=$voxygen_voice&ts=1480362849466"
        printf "$_reset"
    fi
    mpg123 -q "$audio_file" 2>/dev/null #segmentation fault, don't know why but it works...
    return # avoid above error code
}
