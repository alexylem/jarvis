#!/bin/bash
google_STT () { # STT () {} Transcribes audio file $1 and writes corresponding text in $forder
json=`wget -q --post-file $1 --header="Content-Type: audio/l16; rate=16000" -O - "http://www.google.com/speech-api/v2/recognize?client=chromium&lang=$language&key=$google_speech_api_key"`
$verbose && printf "DEBUG: $json\n"
echo $json | perl -lne 'print $1 if m{"transcript":"([^"]*)"}' > $forder
}
