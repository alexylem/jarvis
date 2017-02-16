#!/bin/bash
touch /tmp/jarvis_bing_token # initiate if don't exist
touch /tmp/jarvis_bing_expires # initiate if don't exist

_bing_transcribe () {
    if [ -z "$bing_speech_api_key" ]; then
        echo "" # new line
        jv_error "ERROR: missing bing speech api key"
        jv_warning "HELP: define bing key in Settings > Voice recognition"
        exit 1 # TODO doesn't really exit because launched with & forjv_spinner
    fi
    
    stt_bing_token="`cat /tmp/jarvis_bing_token`"
    stt_bing_expires="`cat /tmp/jarvis_bing_expires`"
    
    if [ -z "$stt_bing_expires" ] || [ "$stt_bing_expires" -lt "`date +%s`" ]; then
        $verbose && jv_debug "DEBUG: token missing or expired"
        # https://github.com/alexylem/jarvis/issues/145
        local json=`curl -X POST "https://api.cognitive.microsoft.com/sts/v1.0/issueToken" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -H "Content-Length: 0" \
            -H "Ocp-Apim-Subscription-Key: $bing_speech_api_key" \
            -d "grant_type=client_credentials" \
            -d "scope=https://speech.platform.bing.com" \
            --silent`
        $verbose && jv_debug "DEBUG: json=$json"
        
        local error=`echo $json | perl -lne 'print $1 if m{"message": "([^"]*)"}'`
        if [ -n "$error" ]; then
            jv_error "ERROR: $error"
            exit 1
        fi
        stt_bing_token="$json"
        echo $stt_bing_token > /tmp/jarvis_bing_token
        
        # TODO expiration date not provided anymore by bing, what to use?
        #local expires_in=`echo $json | perl -lne 'print $1 if m{"expires_in":"([^"]*)"}'`
        local expires_in=$(( 10 * 60 )) # 10 mins
        stt_bing_expires=`echo $(( $(date +%s) + $expires_in - 10 ))` # -10 to compensate webservice call duration
        echo $stt_bing_expires > /tmp/jarvis_bing_expires
        $verbose && jv_debug "DEBUG: token will expire in $(( $stt_bing_expires - `date +%s` )) seconds"
    fi
    
    [[ $OSTYPE = darwin* ]] && uuid=$(uuidgen) || uuid=$(cat /proc/sys/kernel/random/uuid)
    
    local request="https://speech.platform.bing.com/recognize/query"
    request+="?version=3.0"
    request+="&requestid=$uuid"
    request+="&appid=D4D52672-91D7-4C74-8AD8-42B1D98141A5"
    request+="&format=json"
    request+="&locale=${language//_/-}" # fr_FR => fr-FR
    request+="&device.os=$platform"
    request+="&scenarios=ulm"
    request+="&instanceid=E043E4FE-51EF-4B74-8133-B728C4FEA8AA"
    request+="&result.profanitymarkup=0" #with this we avoid the insult with <profanity> tags
    
    $verbose && jv_debug "DEBUG: curl $request"
    # don't use local or else $? will not work
    json=`curl "$request" \
        -H "Host: speech.platform.bing.com" \
        -H "Content-Type: audio/wav; samplerate=16000" \
        -H "Authorization: Bearer $stt_bing_token" \
        --data-binary "@$audiofile" \
        --silent --fail`
    if (( $? )); then
        jv_error "ERROR: bing recognition curl failed"
        exit 1
    fi
    $verbose && jv_debug "DEBUG: json=$json"
    local status=`echo $json | perl -lne 'print $1 if m{"status":"([^"]*)"}'`
    
    if [ "$status" = "success" ]; then
        echo $json | perl -lne 'print $1 if m{"name":"([^"]*)"}' > $forder
    fi
}

# Internal: Speech To Text function for Bing
# Return value: none
# Return code: 0 if success
bing_STT () {
    LISTEN $audiofile || return $?
    _bing_transcribe &
   jv_spinner $!
   return $? # return code of _bing_transcribe
}
