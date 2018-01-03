#!/bin/bash
stt_sb_install () {
    set -e
    local sb_supported_os=false
    echo "1/2 Preparation of dependencies"
    if [ "$platform" = "linux" ]; then
        if [ "$jv_os_name" == "raspbian" ]; then
            if [ "$jv_os_version" -ge 8 ]; then
                sb_supported_os=true
                binaries="rpi-arm-raspbian-8.0-1.1.0"
                jv_install libpython2.7 #755
            fi
        elif [ "$jv_os_name" == "osmc" ]; then #628
            if [[ "$(cat /etc/debian_version)" -ge 8 ]]; then
                sb_supported_os=true
                binaries="rpi-arm-raspbian-8.0-1.1.0"
            fi
        elif [ "$jv_os_name" == "ubuntu" ] && [ "$jv_arch" == "x86_64" ]; then
            case "$jv_os_version" in
                "12.04") 
                    sb_supported_os=true
                    binaries="ubuntu1204-x86_64-1.1.0"
                    ;;
                "14.04"|"16.04")
                    sb_supported_os=true
                    binaries="ubuntu1404-x86_64-1.1.0"
                    ;;
            esac
        fi
        $sb_supported_os && jv_install bzip2 python-pyaudio python3-pyaudio libatlas-base-dev # https://github.com/alexylem/jarvis/issues/327
    elif [ "$platform" = "osx" ]; then
        sb_supported_os=true
        binaries="osx-x86_64-1.1.0"
        jv_install portaudio #551
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
    snowboy_trigger_models=()
    snowboy_trigger_smodels=""
    for model in stt_engines/snowboy/resources/*.[up]mdl; do
        snowboy_model=$(basename "$model")
        model_name="${snowboy_model%.*}"
        snowboy_models+=("${model_name}")
        snowboy_smodels+=" \"$model\"" # in case there are spaces in models for quick commands
        if [ "${model_name}" = "$trigger_sanitized" ]; then
            snowboy_trigger_models+=("${model_name}")
            snowboy_trigger_smodels+=" \"$model\""
        fi
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

    local models=("${snowboy_models[@]}")
    local smodels="$snowboy_smodels"

    # Limit model to trigger one
    if [ -n "$2" ]; then
        models=("${snowboy_trigger_models[@]}")
        smodels="$snowboy_trigger_smodels"
    fi

    if $verbose; then
        $verbose && (IFS=','; jv_debug "DEBUG: models=${models[*]}")
        local quiet=''
    else
        local quiet='2>/dev/null'
    fi;
    
    printf $_gray
    eval "$timeout python stt_engines/snowboy/main.py \
        --models $smodels \
        --sensitivity $snowboy_sensitivity \
        --gain $gain \
        $( $snowboy_checkticks && echo "--tick" ) \
        $quiet &" # http://stackoverflow.com/questions/4339756/inside-a-bash-script-how-to-get-pid-from-a-program-executed-when-using-the-eval
    local pid=$!
    wait $pid # to allow signal trap
    local retcode=$?
    printf $_reset
    local pause_retcode=$((128+$jv_sig_pause))
    local listen_retcode=$((128+$jv_sig_listen))
    case $retcode in
        124)             return 124;; # timeout
        $pause_retcode)  kill $pid # paused by user, kill snowboy
                         return $pause_retcode;;
        $listen_retcode) kill $pid # go in listen mode, kill snowboy
                         echo "$trigger" > $forder # simulate hotword heard
                         return 0;;
    esac
    
    # 0-10 fail  -   11 - 101 ok  - 102-255 fail
    modelid=$(($retcode-11))
    $verbose && jv_debug "DEBUG: modelid=$modelid"
    if [ "$modelid" -lt 0 ] || [ "$modelid" -gt 90 ]; then
        jv_error "ERROR: snowboy recognition failed"
        if $verbose; then
            jv_warning "HELP: check error message above, if:"
            jv_warning "IOError: [Errno Invalid input device (no default output device)] -9996"
            echo       "  1) check your mic in Settings / Audio / Mic"
            echo       "  2) reboot your device"
            echo       "  3) report at: https://github.com/alexylem/jarvis/issues/415"
            jv_warning "IOError: [Errno Invalid sample rate] -9997"
            echo       "  1) check your mic in Settings / Audio / Mic"
            echo       "  2) try uninstalling pulseaudio"
            echo       "  3) try fresh OS install"
            echo       "  4) your mic does not support 16k sampling rate, change mic"
            echo       "  5) report at: https://github.com/alexylem/jarvis/issues/311"
            jv_warning "IOError: [Errno Unanticipated host error] -9999"
            echo       "  1) your mic is in error state, unplug/replug it"
            echo       "  2) report at https://github.com/alexylem/jarvis/issues/20"
            jv_warning "Other"
            echo       "  1) report at https://github.com/alexylem/jarvis/issues/new"
        else
            jv_warning "HELP: run in troubleshooting mode for more information"
        fi
        jv_exit 1
    fi
    echo "${models[modelid]}" > $forder
    return 0 # mandatory
}

# Internal: internal function for snowboy speech to text
# Transcribes input from microphone and writes corresponding text in $forder
# Return 124 if timeout
snowboy_STT () {
    if $bypass; then
        _snowboy_STT 10
        local retcode=$?
        (( $retcode )) && return $retcode
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
        _snowboy_STT "" "trigger"
        local retcode=$?
        (( $retcode )) && return $retcode
        
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
    if [ -z "$snowboy_token" ]; then
        configure "snowboy_token"
        [ -n "$snowboy_token" ] || return 1
    fi
    
    # record 3 audio samples of the hotword
    dialog_msg "We will record now 3 audio samples of '$hotword'\nSample #1\nPres [Enter], say '$hotword' then hit Ctrl+C"
    rec -r 16000 -c 1 -b 16 -e signed-integer /tmp/1.wav gain $gain
    dialog_msg "Sample #2\nPres [Enter], say '$hotword' then hit Ctrl+C"
    rec -r 16000 -c 1 -b 16 -e signed-integer /tmp/2.wav gain $gain
    dialog_msg "Sample #3\nPres [Enter], say '$hotword' then hit Ctrl+C"
    rec -r 16000 -c 1 -b 16 -e signed-integer /tmp/3.wav gain $gain
    
    # get microphone information #103
    #[ "$rec_hw" != "false" ] && local microphone=$(lsusb -d $(cat /proc/asound/card${rec_hw:3:1}/usbid) | cut -c 34-) || local microphone="Default"
    local microphone="Default"
    local language_code="${language:0:2}"
    [ "$language_code" == "de" ] && language_code="dt"
    
    # build json data parameter
    local WAV1=$(base64 /tmp/1.wav)
    local WAV2=$(base64 /tmp/2.wav)
    local WAV3=$(base64 /tmp/3.wav)
    # language forced to en because of https://github.com/Kitt-AI/snowboy/issues/75
    cat <<EOF >/tmp/data.json
{
    "name": "$lowercase",
    "language": "$language_code",
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
        local error="$(cat /tmp/model.pmdl)"
        echo "$error"
        case "$error" in
            *credentials*) jv_error "ERROR: Missing/Invalid Snowboy token"
                           jv_warning "HELP: Your token: $snowboy_token"
                           jv_warning "HELP: Set it in menu Settings / Voice Reco / Snowboy Settings / Token"
                           ;;
            *)             jv_error "ERROR: error occured while training the model"
                           jv_warning "HELP: check error above"
                           ;;
        esac
        exit 1
    fi
    
    # save model
    mv /tmp/model.pmdl "stt_engines/snowboy/resources/$sanitized.pmdl"
    jv_success "Completed"
    
    # reload models
    stt_sb_load
}
