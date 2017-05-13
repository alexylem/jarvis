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
    [ -n "$1" ] || return #591
    local audio_file="$jv_cache_folder/$(jv_sanitize "$1" _).mp3"
    if [ ! -f "$audio_file" ]; then
        $verbose && printf "$_gray" # output in verbose mode will be displayed in gray
        wget $($verbose || echo -q) -U Mozilla -O $audio_file "http://translate.google.com/translate_tts?tl=${language:0:2}&client=tw-ob&ie=UTF-8&q=$1"
        $verbose && printf "$_reset"
    else
        $verbose && jv_debug "DEBUG: using cache $audio_file"
    fi
    jv_play "$audio_file"
}
