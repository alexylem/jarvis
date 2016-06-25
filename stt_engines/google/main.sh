#!/bin/bash
_google_transcribe () {
    json=`wget -q --post-file $audiofile --header="Content-Type: audio/l16; rate=16000" -O - "http://www.google.com/speech-api/v2/recognize?client=chromium&lang=$language&key=$google_speech_api_key"`
    $verbose && printf "DEBUG: $json\n"
    echo $json | perl -lne 'print $1 if m{"transcript":"([^"]*)"}' > $forder
}

google_STT () { # STT () {} Listen & transcribes audio file then writes corresponding text in $forder
    LISTEN $audiofile
    _google_transcribe &
    spinner $!
}
