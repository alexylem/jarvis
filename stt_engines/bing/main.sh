#!/bin/bash
touch /tmp/jarvis_bing_token # initiate if don't exist
touch /tmp/jarvis_bing_expires # initiate if don't exist

_bing_transcribe () {
    if [ -z "$bing_speech_api_key1" ] || [ -z "$bing_speech_api_key2" ]; then
        echo "" # new line
        echo "ERROR: missing bing speech api key"
        echo "HELP: define bing keys in Settings > Voice recognition"
        echo "" > $forder # clean previous order to show "?"
        exit 1 # TODO doesn't really exit because launched with & for spinner
    fi
    
    stt_bing_token="`cat /tmp/jarvis_bing_token`"
    stt_bing_expires="`cat /tmp/jarvis_bing_expires`"
    
    if [ -z "$stt_bing_expires" ] || [ "$stt_bing_expires" -lt "`date +%s`" ]; then
        $verbose && echo "DEBUG: token missing or expired"
        local json=`curl -X POST "https://oxford-speech.cloudapp.net/token/issueToken" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "grant_type=client_credentials" \
            -d "client_id=$bing_speech_api_key1" \
            -d "client_secret=$bing_speech_api_key2" \
            -d "scope=https://speech.platform.bing.com" \
            --silent`
        $verbose && echo "DEBUG: json=$json"
        
        stt_bing_token=`echo $json | perl -lne 'print $1 if m{"access_token":"([^"]*)"}'`
        echo $stt_bing_token > /tmp/jarvis_bing_token
        
        if [ -z "$stt_bing_token" ]; then
            error=`echo $json | perl -lne 'print $1 if m{"message": "([^"]*)"}'`
            echo "ERROR: $error"
            exit 1
        fi
        
        local expires_in=`echo $json | perl -lne 'print $1 if m{"expires_in":"([^"]*)"}'`
        stt_bing_expires=`echo $(( $(date +%s) + $expires_in - 10 ))` # -10 to compensate webservice call duration
        echo $stt_bing_expires > /tmp/jarvis_bing_expires
        $verbose && echo "DEBUG: token will expire in $(( $stt_bing_expires - `date +%s` )) seconds"
    fi
    
    local request="https://speech.platform.bing.com/recognize/query"
    request+="?version=3.0"
    request+="&requestid=`uuidgen`"
    request+="&appid=D4D52672-91D7-4C74-8AD8-42B1D98141A5"
    request+="&format=json"
    request+="&locale=${language//_/-}" # fr_FR => fr-FR
    request+="&device.os=$platform"
    request+="&scenarios=ulm"
    request+="&instanceid=E043E4FE-51EF-4B74-8133-B728C4FEA8AA"
    
    $verbose && echo "DEBUG: curl $request"
    # don't use local or else $? will not work
    json=`curl "$request" \
        -H "Host: speech.platform.bing.com" \
        -H "Content-Type: audio/wav; samplerate=16000" \
        -H "Authorization: Bearer $stt_bing_token" \
        --data-binary "@$audiofile" \
        --silent --fail`
    if (( $? )); then
        echo "ERROR: bing recognition curl failed"
        exit 1
    fi
    $verbose && echo "DEBUG: json=$json"
    local status=`echo $json | perl -lne 'print $1 if m{"status":"([^"]*)"}'`
    
    if [ "$status" = "success" ]; then
        echo $json | perl -lne 'print $1 if m{"name":"([^"]*)"}' > $forder
    fi
}

bing_STT () {
    LISTEN $audiofile
    _bing_transcribe &
    spinner $!
}
