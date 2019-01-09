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
    if [ -z "$bing_speech_api_region" ]; then
        echo "" # new line
        jv_error "ERROR: missing bing speech api region"
        jv_warning "HELP: define bing key in Settings > Voice recognition"
        exit 1 # TODO doesn't really exit because launched with & forjv_spinner
    fi

    stt_bing_region="${bing_speech_api_region}" # TODO integrate parameters to jarvis main config
    stt_bing_token="`cat /tmp/jarvis_bing_token`"
    stt_bing_expires="`cat /tmp/jarvis_bing_expires`"

    if [ -z "$stt_bing_expires" ] || [ "$stt_bing_expires" -lt "`date +%s`" ]; then
        $verbose && jv_debug "DEBUG: token missing or expired"
        # https://github.com/alexylem/jarvis/issues/145
        local json=`curl -X POST "https://${stt_bing_region}.api.cognitive.microsoft.com/sts/v1.0/issueToken" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -H "Content-Length: 0" \
            -H "Ocp-Apim-Subscription-Key: $bing_speech_api_key" \
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
        local expires_in=$(( 10 * 60 )) # 10 mins
        stt_bing_expires=`echo $(( $(date +%s) + $expires_in - 10 ))` # -10 to compensate webservice call duration
        echo $stt_bing_expires > /tmp/jarvis_bing_expires
        $verbose && jv_debug "DEBUG: token will expire in $(( $stt_bing_expires - `date +%s` )) seconds"
    fi

    local request="https://${stt_bing_region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1"
    request+="?language=${language//_/-}"
    request+="&format=detailed"
    request+="&profanity=removed" #removing insults from the result

    json=`curl "$request" \
        -H "Host: ${stt_bing_region}.stt.speech.microsoft.com" \
        -H "Content-Type: audio/wav; codec=audio/pcm; samplerate=16000" \
        -H "Authorization: Bearer $stt_bing_token" \
        -H "Accept: application/json" \
        --data-binary "@$audiofile" \
        --silent --fail`
    if (( $? )); then
        jv_error "ERROR: bing recognition curl failed"
        exit 1
    fi
    $verbose && jv_debug "DEBUG: curl post=$json"

    local status=$(jq -r '.RecognitionStatus' <(echo $json))
    $verbose && jv_debug "DEBUG: status=${status}"

    if [[ $status = "Success" ]]; then
        echo $json | jq '.NBest[] .Display' > $forder
        $verbose && jv_debug "DEBUG ${forder}=$(cat $forder)"
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
