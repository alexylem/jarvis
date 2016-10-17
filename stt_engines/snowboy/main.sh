#!/bin/bash
[ -f "`dirname "${BASH_SOURCE[0]}"`/_snowboydetect.so" ] || {
    dialog_yesno "Snowboy doesn't seem to be installed.\nDo you want to install it?" true >/dev/null && {
        set -e
        echo "1/2 Preparation of dependencies"
        if [[ "$platform" == "linux" ]]; then
            sudo apt-get install -y python-pyaudio python3-pyaudio libatlas-base-dev
            binaries="rpi-arm-raspbian-8.0-1.0.2"
        elif [[ "$platform" == "osx" ]]; then
            brew install portaudio
            binaries="osx-x86_64-1.0.2"
        else
            dialog_msg "Unknown platform"
            exit 1
        fi
        wget https://bootstrap.pypa.io/get-pip.py
        sudo python get-pip.py
        rm get-pip.py
        sudo pip install pyaudio
        echo "2/2 Installation of Snowboy"
        cd `dirname "${BASH_SOURCE[0]}"`
        wget https://s3-us-west-2.amazonaws.com/snowboy/snowboy-releases/$binaries.tar.bz2
        tar xvjf $binaries.tar.bz2
        rm $binaries.tar.bz2
        mv $binaries/_snowboydetect.so .
        cp $binaries/snowboydetect.py .
        cp $binaries/snowboydecoder.py .
        cp -r $binaries/resources .
        rm -rf $binaries
        cd "$DIR"
        dialog_msg "Installation Completed"
    }
}

stt_sb_load () {
    # build list of models to pass in parameter
    snowboy_models=()
    snowboy_smodels=""
    for model in stt_engines/snowboy/resources/*mdl; do
        snowboy_model=$(basename "$model")
        snowboy_models+=("${snowboy_model%.*}")
        snowboy_smodels+=" \"$model\"" # in case there are spaces in models for quick commands
    done
}
stt_sb_load # load models at startup

snowboy_STT () { # STT () {} Transcribes audio file $1 and writes corresponding text in $forder
    shopt -s nocasematch
    
    if $verbose; then
        $verbose && (IFS=','; jv_debug "DEBUG: models=${snowboy_models[*]}")
        local quiet=''
        printf $_gray
    else
        local quiet='2>/dev/null'
    fi;
    
    # check if model already exists for trigger
    # exit if model already exists for trigger
    if [[ ! -f "stt_engines/snowboy/resources/$trigger_sanitized.pmdl" && ! -f "stt_engines/snowboy/resources/$trigger_sanitized.umdl" ]]; then
        jv_error "\nERROR: personal model for '$trigger' not found"
        jv_success "HELP: See how to create '$trigger_sanitized.pmdl' here:"
        jv_success "HELP: http://domotiquefacile.fr/jarvis/content/snowboy"
        jv_success "HELP: Or change your hotword to default model 'snowboy':"
        jv_success "HELP: Settings > General > Magic word"
        jv_exit 1
    fi
    
    #local model="snowboy.umdl"
    #[ $trigger != "SNOWBOY" ] && model="$(tr '[:upper:]' '[:lower:]' <<< $trigger).pmdl"
    
    eval python stt_engines/snowboy/main.py $snowboy_sensitivity $snowboy_smodels $quiet #TODO on mac: WARNING:  140: This application, or a library it uses, is using the deprecated Carbon Component Manager for hosting Audio Units. Support for this will be removed in a future release. Also, this makes the host incompatible with version 3 audio units. Please transition to the API's in AudioComponent.h.
    # 0-10 fail  -   11 - 101 ok  - 102-255 fail
    modelid=$(($?-11))
    $verbose && echo "DEBUG: modelid=$modelid"
    if [ "$modelid" -lt 0 ] || [ "$modelid" -gt 90 ]; then
        jv_error "ERROR: snowboy recognition failed"
        jv_exit 1
    else
        local order="${snowboy_models[modelid]}"
        [[ "$order" == "$trigger_sanitized" ]] || bypass=true # case insensitive comparison ex for snowboy
        echo "$order" > $forder
    fi
    printf $_reset
}

stt_sb_train () {
    # Usage: tts_sb_train "Hey Jarvis" [true]
    # $1: the string to train
    # $2: (optional) force re-retrain in case model already exists
    # Contributor: taostaos - https://github.com/taostaos
    local hotword="$1"
    local -r force_retrain=$2
    local lowercase="$(echo $hotword | tr '[:upper:]' '[:lower:]')"
    local sanitized="$(jv_sanitize "$hotword")"
    
    # exit if model already exists for trigger
    [ -z "$force_retrain" ] && [[ -f "stt_engines/snowboy/resources/$sanitized.pmdl" || -f "stt_engines/snowboy/resources/$sanitized.umdl" ]] && return 0
    
    # check token is in config
    if [ -f "config/snowboy_token" ]; then
        # load token from config
        local snowboy_token="$(cat config/snowboy_token)"
    else
        # ask token to user
        local snowboy_token="$(dialog_input "Kitt.ai Token\nGet one at: https://snowboy.kitt.ai")"
        # save token in config
        echo "$snowboy_token" > config/snowboy_token
    fi
    
    # record 3 audio samples of the hotword
    dialog_msg "We will record now 3 audio samples of '$hotword'\nSample #1\nPres [Enter], say '$hotword' then hit Ctrl+C"
    rec -r 16000 -c 1 -b 16 -e signed-integer /tmp/1.wav
    dialog_msg "Sample #2\nPres [Enter], say '$hotword' then hit Ctrl+C"
    rec -r 16000 -c 1 -b 16 -e signed-integer /tmp/2.wav
    dialog_msg "Sample #3\nPres [Enter], say '$hotword' then hit Ctrl+C"
    rec -r 16000 -c 1 -b 16 -e signed-integer /tmp/3.wav
    
    # get microphone information
    [ "$rec_hw" != "false" ] && local microphone=$(lsusb -d $(cat /proc/asound/card${rec_hw:3:1}/usbid) | cut -c 34-) || local microphone="Default"
    
    # build json data parameter
    local WAV1=$(base64 /tmp/1.wav)
    local WAV2=$(base64 /tmp/2.wav)
    local WAV3=$(base64 /tmp/3.wav)
    # language forced to en because of https://github.com/Kitt-AI/snowboy/issues/75
    cat <<EOF >/tmp/data.json
{
    "name": "$lowercase",
    "language": "en",
    "microphone": "$microphone",
    "token": "$snowboy_token",
    "voice_samples": [
        {"wave": "$WAV1"},
        {"wave": "$WAV2"},
        {"wave": "$WAV3"}
    ]
}
EOF
    
    # call kitt.ai endpoint with recorded samples to get model
    echo "Training model..."
    response_code=$(curl "https://snowboy.kitt.ai/api/v1/train/" \
        --progress-bar \
        --header "Content-Type: application/json" \
        --data   @/tmp/data.json \
        --write-out "%{http_code}" \
        --output /tmp/model.pmdl)
    #local response_code=$? # sometimes 0 although it failed with 400 http code
    
    # check if there was an error
    if [ "${response_code:0:1}" != "2" ]; then
        cat /tmp/model.pmdl
        echo # carriage return
        jv_error "ERROR: error occured while training the model"
        exit 1
    fi
    
    # save model
    mv /tmp/model.pmdl "stt_engines/snowboy/resources/$sanitized.pmdl"
    jv_success "Completed"
    
    # reload models
    stt_sb_load
}
