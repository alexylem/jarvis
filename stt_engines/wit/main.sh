#!/bin/bash
_wit_transcribe () {
    json=`curl -XPOST 'https://api.wit.ai/speech?v=20141022' -s -L -H "Authorization: Bearer $wit_server_access_token" -H "Content-Type: audio/wav" --data-binary "@$audiofile"`
    $verbose && jv_debug "DEBUG: $json"
    echo $json | perl -lne 'print $1 if m{"_text" : "([^"]*)"}' > $forder
}

wit_STT () { # STT () {} Transcribes audio file $1 and writes corresponding text in $forder
    LISTEN $audiofile || return $?
    _wit_transcribe &
   jv_spinner $!
}
