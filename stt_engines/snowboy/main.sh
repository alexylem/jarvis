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

# build list of models to pass in parameter
snowboy_models=()
snowboy_smodels=""
for model in stt_engines/snowboy/resources/*mdl; do
    snowboy_model=$(basename "$model")
    snowboy_models+=("${snowboy_model%.*}")
    snowboy_smodels+=" \"$model\"" # in case there are spaces in models for quick commands
done

snowboy_STT () { # STT () {} Transcribes audio file $1 and writes corresponding text in $forder
    shopt -s nocasematch
    
    if $verbose; then
        $verbose && (IFS=','; my_debug "DEBUG: models=${snowboy_models[*]}")
        local quiet=''
        printf $_gray
    else
        local quiet='2>/dev/null'
    fi;
    
    # checking if model exists for trigger
    local trigger_missing=true
    for model in ${snowboy_models[*]}; do
        [[ "$model" == "$trigger" ]] && trigger_missing=false
    done
    if $trigger_missing; then
        my_error "\nERROR: personal model for '$trigger' not found"
        my_success "HELP: See how to create '$(echo $trigger | tr '[:upper:]' '[:lower:]').pmdl' here:"
        my_success "HELP: https://github.com/alexylem/jarvis/wiki/snowboy"
        my_success "HELP: Or change your hotword to default model 'snowboy':"
        my_success "HELP: Settings > General > Magic word"
        program_exit 1
    fi
    
    #local model="snowboy.umdl"
    #[ $trigger != "SNOWBOY" ] && model="$(tr '[:upper:]' '[:lower:]' <<< $trigger).pmdl"
    
    eval python stt_engines/snowboy/main.py $snowboy_sensitivity $snowboy_smodels $quiet #TODO on mac: WARNING:  140: This application, or a library it uses, is using the deprecated Carbon Component Manager for hosting Audio Units. Support for this will be removed in a future release. Also, this makes the host incompatible with version 3 audio units. Please transition to the API's in AudioComponent.h.
    modelid=$(($?-1)) #TODO snowboy returns 1 if error loading .so https://github.com/alexylem/jarvis/issues/79 
    $verbose && echo "DEBUG: modelid=$modelid"
    if [ "$modelid" -gt 100 ]; then
        my_error "ERROR: snowboy recognition failed"
        exit 1
    else
        local order="${snowboy_models[$modelid]}"
        [[ "$order" == "$trigger" ]] || bypass=true
        echo "$order" > $forder
    fi
    printf $_reset
}
