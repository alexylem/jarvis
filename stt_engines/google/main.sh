#!/bin/bash
_google_transcribe () {
    if [ -z "$google_speech_api_key" ]; then
        echo "" # new line
        jv_error "ERROR: missing google speech api key"
        jv_warning "HELP: define google key in Settings > Voice recognition"
        echo "" > $forder # clean previous order to show "?"
        exit 1 # TODO doesn't really exit because launched with & forjv_spinner
    fi
    
    json=`wget -q --post-file $audiofile --header="Content-Type: audio/l16; rate=16000" -O - "http://www.google.com/speech-api/v2/recognize?client=chromium&lang=$language&key=$google_speech_api_key"`
    $verbose && jv_debug "DEBUG: $json"
    echo $json | perl -lne 'print $1 if m{"transcript":"([^"]*)"}' > $forder
}

google_STT () { # STT () {} Listen & transcribes audio file then writes corresponding text in $forder
    LISTEN $audiofile
    _google_transcribe &
   jv_spinner $!
}
