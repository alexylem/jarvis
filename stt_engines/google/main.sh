#!/bin/bash
_google_transcribe () {
    if [ -z "$google_speech_api_key" ]; then
        echo "" # new line
        jv_error "ERROR: missing google speech api key"
        jv_warning "HELP: define google key in Settings > Voice recognition"
        exit 1 # TODO doesn't really exit because launched with & forjv_spinner
    fi
    
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 
    transcribed="`$DIR/google-speech-api.perl $google_speech_api_key $audiofile | jq '.results[0].alternatives[0].transcript'`"
    
    $verbose && jv_debug "DEBUG: $transcribed"
    if [[ $transcribed == "null" ]]; then
        jv_error "ERROR: Google recognition failed"
        exit 1
    fi

    echo $transcribed > $forder
}

google_STT () { # STT () {} Listen & transcribes audio file then writes corresponding text in $forder
    LISTEN $audiofile || return $?
    _google_transcribe &
   jv_spinner $!
}
