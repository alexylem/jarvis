#!/bin/bash
_google_transcribe () {
    if [ -z "$google_speech_api_key" ]; then
        echo "" # new line
        my_error "ERROR: missing google speech api key"
        my_warning "HELP: define google key in Settings > Voice recognition"
        echo "" > $forder # clean previous order to show "?"
        exit 1 # TODO doesn't really exit because launched with & for spinner
    fi
    AUDIO=$(cat $audiofile | base64)
    cat <<EOF > /tmp/postfile
{
      "audio": {
        "content": "$AUDIO"
      },
      "config": {
        "encoding": "LINEAR16",
        "languageCode": "fr",
        "maxAlternatives": 1,
        "sampleRate": 16000
      }
}
EOF
    json=`wget -q --post-file /tmp/postfile --header="Content-Type: application/json" -O - "https://speech.googleapis.com/v1beta1/speech:syncrecognize?key=$google_speech_api_key"`
    $verbose && my_debug "DEBUG: $json"
    echo $json | jq '.results[].alternatives[].transcript' > $forder
}

google_STT () { # STT () {} Listen & transcribes audio file then writes corresponding text in $forder
    LISTEN $audiofile
    _google_transcribe &
    spinner $!
}
