#!/bin/bash
stt_sb_install () {
    set -e
    local sb_supported_os=false
    echo "1/2 Preparation of dependencies"
    if [ "$platform" = "linux" ]; then
        if [ "$jv_os_name" == "raspbian" ]; then
            if [ "$jv_os_version" == 8 ]; then
                sb_supported_os=true
                binaries="rpi-arm-raspbian-8.0-1.1.0"
            fi
        elif [ "$jv_os_name" == "ubuntu" ]; then
            if [ "$jv_arch" == "x86_64" ] && ([ "$jv_os_version" == "12.04" ] || [ "$jv_os_version" == "14.04" ]); then
                sb_supported_os=true
                binaries="ubuntu${jv_os_version/.}-x86_64-1.1.0" # 12.04 => 1204
            fi
        fi
        $sb_supported_os && jv_install python-pyaudio python3-pyaudio libatlas-base-dev
    elif [ "$platform" = "osx" ]; then
        sb_supported_os=true
        binaries="osx-x86_64-1.1.0"
        jv_install portaudio
    fi
    if [ "$sb_supported_os" == false ]; then
        dialog_msg <<EOM
Pre-packaged Snowboy binaries only available for:
- Rasbpian 8 Jessie on Raspberry Pi
- Ubuntu 12.04 and 14.04 on x86 64bits
- Mac OS X
Please use correct distribution or compile your own version of Snowboy:
https://github.com/kitt-ai/snowboy
EOM
        exit 1
    fi
    jv_install bzip2 # https://github.com/alexylem/jarvis/issues/327
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
    cd "$jv_dir"
}

[ -f "`dirname "${BASH_SOURCE[0]}"`/_snowboydetect.so" ] || {
    dialog_yesno "Snowboy doesn't seem to be installed.\nDo you want to install it?" true >/dev/null && {
        stt_sb_install
        dialog_msg "Snowboy installed sucessfully"
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

# Internal: hidden function to launch snowboy recognition
# $1 - timeout in secs, default false (no timeout)
# Write recognized model text to $forder
# Returns 124 if timeout
# Exits if error
_snowboy_STT () {
    [ -n "$1" ] && local timeout="utils/timeout.sh $1" || local timeout=""
    
    if $verbose; then
        $verbose && (IFS=','; jv_debug "DEBUG: models=${snowboy_models[*]}")
        local quiet=''
    else
        local quiet='2>/dev/null'
    fi;
    
    printf $_gray
    eval $timeout python stt_engines/snowboy/main.py $snowboy_sensitivity $snowboy_smodels $quiet #TODO on mac: WARNING:  140: This application, or a library it uses, is using the deprecated Carbon Component Manager for hosting Audio Units. Support for this will be removed in a future release. Also, this makes the host incompatible with version 3 audio units. Please transition to the API's in AudioComponent.h.
    local retcode=$?
    printf $_reset
    [ $retcode -eq 124 ] && return 124 # timeout
    
    # 0-10 fail  -   11 - 101 ok  - 102-255 fail
    modelid=$(($retcode-11))
    $verbose && jv_debug "DEBUG: modelid=$modelid"
    if [ "$modelid" -lt 0 ] || [ "$modelid" -gt 90 ]; then
        jv_error "ERROR: snowboy recognition failed"
        jv_exit 1
    fi
    echo "${snowboy_models[modelid]}" > $forder
    return 0 # mandatory
}

# Internal: internal function for snowboy speech to text
# Transcribes input from microphone and writes corresponding text in $forder
# Return 124 if timeout
snowboy_STT () {
    if $bypass; then
        _snowboy_STT 10
        [ $? -eq 124 ] && return 124 # timeout
    else
        # check if model already exists for trigger
        # exit if model already exists for trigger
        if [[ ! -f "stt_engines/snowboy/resources/$trigger_sanitized.pmdl" && ! -f "stt_engines/snowboy/resources/$trigger_sanitized.umdl" ]]; then
            jv_error "\nERROR: personal model for '$trigger' not found"
            jv_warning "HELP: Train '$trigger_sanitized.pmdl' in:"
            jv_warning "HELP: Settings > Voice Recognition > Snowboy settings > Train"
            jv_warning "HELP: Or change your hotword to default model 'snowboy' in:"
            jv_warning "HELP: Settings > General > Magic word"
            jv_exit 1
        fi
        _snowboy_STT
        order="$(cat $forder)"
        
        shopt -s nocasematch
        if [[ "$order" != "$trigger_sanitized" ]]; then # case insensitive comparison
            if [ $command_stt == 'snowboy' ]; then
                # quick commands not allowed here
                if $verbose; then
                    jv_warning "WARNING: Quick commands are ignored if STT for commands is snowboy"
                    jv_warning "HELP: Say \"$trigger\" before to enter in conversation mode"
                    jv_warning "HELP: Or choose another STT for commands"
                fi
                # empty order to consider as not recognized
                order=""
            else
                # quick commands are allowed here
                bypass=true # force conversation mode
            fi
        fi
    fi
    return 0 # mandatory
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
    [ -z "$snowboy_token" ] && configure "snowboy_token"
    
    # record 3 audio samples of the hotword
    dialog_msg "We will record now 3 audio samples of '$hotword'\nSample #1\nPres [Enter], say '$hotword' then hit Ctrl+C"
    rec -r 16000 -c 1 -b 16 -e signed-integer /tmp/1.wav
    dialog_msg "Sample #2\nPres [Enter], say '$hotword' then hit Ctrl+C"
    rec -r 16000 -c 1 -b 16 -e signed-integer /tmp/2.wav
    dialog_msg "Sample #3\nPres [Enter], say '$hotword' then hit Ctrl+C"
    rec -r 16000 -c 1 -b 16 -e signed-integer /tmp/3.wav
    
    # get microphone information #103
    #[ "$rec_hw" != "false" ] && local microphone=$(lsusb -d $(cat /proc/asound/card${rec_hw:3:1}/usbid) | cut -c 34-) || local microphone="Default"
    local microphone="Default"
    
    # build json data parameter
    local WAV1=$(base64 /tmp/1.wav)
    local WAV2=$(base64 /tmp/2.wav)
    local WAV3=$(base64 /tmp/3.wav)
    # language forced to en because of https://github.com/Kitt-AI/snowboy/issues/75
    cat <<EOF >/tmp/data.json
{
    "name": "$lowercase",
    "language": "${language:0:2}",
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
