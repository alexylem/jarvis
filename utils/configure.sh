#!/bin/bash
# Configuration
configure () {
    local variables=('google_speech_api_key'
                   'bing_speech_api_key'
                   'check_updates'
                   'command_stt'
                   'conversation_mode'
                   'dictionary'
                   'gain'
                   'google_speech_api_key'
                   'jv_branch'
                   'jv_bt_device_mac'
                   'jv_bt_device_name'
                   'jv_timeout'
                   'jv_use_bluetooth'
                   'language'
                   'language_model'
                   'trigger_mode'
                   'min_noise_duration_to_start'
                   'min_noise_perc_to_start'
                   'min_silence_duration_to_stop'
                   'min_silence_level_to_stop'
                   'osx_say_voice'
                   'phrase_failed'
                   'phrase_misunderstood'
                   'phrase_triggered'
                   'phrase_welcome'
                   'play_hw'
                   'pocketsphinxlog'
                   'rec_hw'
                   'recorder'
                   'send_usage_stats'
                   'separator'
                   'show_commands'
                   'snowboy_checkticks'
                   'snowboy_sensitivity'
                   'snowboy_token'
                   'tempo'
                   'trigger'
                   'trigger_stt'
                   'trigger_mode'
                   'tts_engine'
                   'username'
                   #'voxygen_voice'
                   'wit_server_access_token')
    local hooks=(  'entering_cmd'
                   'exiting_cmd'
                   'program_startup'
                   'program_exit'
                   'start_listening'
                   'stop_listening'
                   'start_speaking'
                   'stop_speaking'
                   'listening_timeout')
    case "$1" in
        google_speech_api_key)   eval "$1=\"$(dialog_input "Google Speech API Key\nNot free, see https://cloud.google.com/speech/docs/getting-started" "${!1}" true)\"";;
        bing_speech_api_key)   eval "$1=\"$(dialog_input "Bing Speech API Key\nHow to get one: http://openjarvis.com/content/bing" "${!1}" true)\"";;
        check_updates)         options=('Always' 'Daily' 'Weekly' 'Never')
                               case "$(dialog_select "Check Updates when Jarvis starts up\nRecommended: Daily" options[@] "Daily")" in
                                   Always) check_updates=0;;
                                   Daily)  check_updates=1;;
                                   Weekly) check_updates=7;;
                                   Never)  check_updates=false;;
                               esac;;
        command_stt)           options=('google' 'bing' 'wit' 'snowboy' 'pocketsphinx')
                               eval "$1=\"$(dialog_select "Which engine to use for the recognition of commands\nVisit http://openjarvis.com/content/stt\nRecommended: bing" options[@] "${!1}")\""
                               [ "$command_stt" == "snowboy" ] && dialog_msg "Attention: Snowboy for commands will only be able to understand trained commands.\nTrain your commands in Settings > Voice Reco > Snowboy Settings > Train..."
                               source stt_engines/$command_stt/main.sh;;
        conversation_mode)     eval "$1=\"$(dialog_yesno "Wait for another command after first executed" "${!1}")\"";;
        dictionary)            eval "$1=\"$(dialog_input "PocketSphinx dictionary file" "${!1}")\"";;
        gain)                  eval "$1=\"$(dialog_input "Microphone gain\nCan be positive of negative integer, ex: -5, 0, 10...\nAdjust it by steps of 5, or less to finetune" "${!1}" true)\"";;
        google_speech_api_key) eval "$1=\"$(dialog_input "Google Speech API Key\nHow to get one: http://stackoverflow.com/a/26833337" "${!1}")\"";;
        jv_branch)             options=("master" "beta")
                               eval "$1=\"$(dialog_select "Repository branch to use for Jarvis updates\nRecommended: master" options[@] "${!1}")\""
                               git checkout $jv_branch || {
                                   jv_error "ERROR: an error has occured while checking out $jv_branch branch"
                                   jv_press_enter_to_continue
                               };;
        jv_timeout)            eval "$1=\"$(dialog_input "Delay during voice command input before timeout\nDefault: 10" "${!1}")\"";;
        jv_use_bluetooth)      eval "$1=\"$(dialog_yesno "Do you want to use a bluetooth Speaker?\nThis will start PulseAudio" "${!1}")\""
                               $jv_use_bluetooth && pulseaudio --start || pulseaudio --kill
                               ;;
        program_startup)       editor hooks/$1;;
        program_exit)          editor hooks/$1;;
        entering_cmd)          editor hooks/$1;;
        exiting_cmd)           editor hooks/$1;;
        start_listening)       editor hooks/$1;;
        stop_listening)        editor hooks/$1;;
        start_speaking)        editor hooks/$1;;
        stop_speaking)         editor hooks/$1;;
        listening_timeout)     editor hooks/$1;;
        language)              options=("de_DE (Deutsch)"
                                        "en_GB (English)"
                                        "es_ES (Español)"
                                        "fr_FR (Français)"
                                        "it_IT (Italiano)"
                                        "pt_PT (Português)")
                               language="$(dialog_select "Language" options[@] "$language")"
                               language="${language% *}" # "fr_FR (Français)" => "fr_FR"
                               ;;
        language_model)        eval "$1=\"$(dialog_input "PocketSphinx language model file" "${!1}")\"";;
        load)
            source defaults/jarvis-config-default.sh
            #[ -f jarvis-config.sh ] && source jarvis-config.sh # backward compatibility
            for hook in "${hooks[@]}"; do
                if [ ! -f "hooks/$hook" ]; then
                    cp hooks/$hook.default hooks/$hook
                fi
            done
            local not_installed=1
            for varname in "${variables[@]}"; do
                if [ -f "config/$varname" ]; then
                    eval "$varname=\"$(cat config/$varname)\""
                    not_installed=0
                fi
            done
            if [ "$tts_engine" == "voxygen" ]; then
                jv_error "Voxygen speech engine has been removed as no longer supported"
                jv_debug "See https://github.com/alexylem/jarvis/issues/446"
                jv_warning "Change your speech engine in Settings > Speech synthesis"
            fi
            return $not_installed;;
        min_noise_duration_to_start)    eval "$1=\"$(dialog_input "Min noise duration to start" "${!1}")\"";;
        min_noise_perc_to_start)        eval "$1=\"$(dialog_input "Min noise percentage to start" "${!1}")\"";;
        min_silence_duration_to_stop)   eval "$1=\"$(dialog_input "Min silence duration to stop" "${!1}")\"";;
        min_silence_level_to_stop)      eval "$1=\"$(dialog_input "Min silence level to stop" "${!1}")\"";;
        osx_say_voice)
            local voices=($(/usr/bin/say -v ? | grep $language | awk '{print $1}'))
            eval "$1=\"$(dialog_select "Select a voice for $language" voices[@] ${!1})\"";;
        phrase_failed)                  eval "$1=\"$(dialog_input 'What to say if user command failed' "${!1}")\"";;
        phrase_misunderstood)           eval "$1=\"$(dialog_input 'What to say if order not recognized' "${!1}")\"";;
        phrase_triggered)               eval "$1=\"$(dialog_input 'What to say when magic word is heard\nEx: Yes?' "${!1}")\"";;
        phrase_welcome)                 eval "$1=\"$(dialog_input 'What to say at program startup' "${!1}")\"";;
        play_hw)
            play_hw="${play_hw:-false}"
            while true; do
                #dialog_msg "Checking audio output, make sure your speakers are on and press [Ok]"
                if dialog_yesno "Checking audio output, make sure your speakers are on and press [Yes].\nPress [No] if you don't have speakers." true >/dev/null; then
                    play "sounds/applause.wav"
                    dialog_yesno "Did you hear something?" true >/dev/null && break
                    clear
                    jv_warning "Selection of the speaker device"
                    aplay -l
                    read -p "Indicate the card # to use [0-9]: " card
                    read -p "Indicate the device # to use [0-9]: " device
                    play_hw="hw:$card,$device"
                    #IFS=$'\n'
                    #devices=(`aplay -l | grep ^card`)
                    #device=`dialog_select "Select a speaker" devices[@]`
                    #play_hw=`echo $device | sed -rn 's/card ([0-9]+)[^,]*, device ([0-9]+).*/hw:\1,\2/p'`
                    update_alsa $play_hw $rec_hw
                else
                    play_hw=""
                    break
                fi
            done
            ;;
        pocketsphinxlog) eval "$1=\"$(dialog_input "File to store PocketSphinx logs" "${!1}")\"";;
        rec_hw)
            rec_hw="${rec_hw:-false}"
            while true; do
                if dialog_yesno "Checking audio input, make sure your microphone is on, press [Yes] and say something.\nPress [No] if you don't have a microphone." true >/dev/null; then
                    clear
                    rec -r 16000 -c 1 -b 16 -e signed-integer $audiofile trim 0 3
                    if [ $? -eq 0 ]; then
                        play $audiofile
                        dialog_yesno "Did you hear yourself?" true >/dev/null && break
                    fi
                    jv_warning "Selection of the microphone device"
                    arecord -l
                    read -p "Indicate the card # to use [0-9]: " card
                    read -p "Indicate the device # to use [0-9]: " device
                    rec_hw="hw:$card,$device"
                    #IFS=$'\n'
                    #devices=(`arecord -l | grep ^card`)
                    #device=`dialog_select "Select a microphone" devices[@]`
                    #rec_hw=`echo $device | sed -rn 's/card ([0-9]+)[^,]*, device ([0-9]+).*/hw:\1,\2/p'`
                    update_alsa $play_hw $rec_hw
                else
                    rec_hw=""
                    break
                fi
            done
            ;;
        recorder)            options=("snowboy" "sox")
                             eval "$1=\"$(dialog_select "Method to record commands from microphone" options[@] "${!1}")\""
                             source recorders/$recorder/main.sh
                             ;;
        save) for varname in "${variables[@]}"; do
                  #echo "DEBUG: saving ${!varname} into config/$varname"
                  echo "${!varname}" > config/$varname
              done;;
        send_usage_stats)    eval "$1=\"$(dialog_yesno "Send anynomous usage statistics to help improving Jarvis" "${!1}")\"";;
        separator)           eval "$1=\"$(dialog_input "Separator for multiple commands at once\nex: 'then' or empty to disable" "${!1}")\"";;
        show_commands)       eval "$1=\"$(dialog_yesno "Show commands on startup and possible answers" "${!1}")\"";;
        snowboy_checkticks)  eval "$1=\"$(dialog_yesno "Check ticks?\nReduce false positives but slower to react" "${!1}")\"";;
        snowboy_sensitivity) eval "$1=\"$(dialog_input "Snowboy sensitivity from 0 (strict) to 1 (permissive)\nRecommended value: 0.4" "${!1}")\"";;
        snowboy_token)       eval "$1=\"$(dialog_input "Snowboy token\nGet one at: https://snowboy.kitt.ai (in profile settings)" "${!1}" true)\"";;
        tempo)               eval "$1=\"$(dialog_input "Speech playback speed\nOriginal: 1.0" "${!1}" true)\"";;
        trigger)             local trigger_old="$trigger"
                             eval "$1=\"$(dialog_input "How would you like your Jarvis to be called?\n(Hotword to be said before speaking commands)" "${!1}" true)\""
                             if [ "$trigger_stt" = "snowboy" ]; then
                                 source stt_engines/$trigger_stt/main.sh # sourced after main menu in jarvis.sh
                                 stt_sb_train "$trigger" || trigger="$trigger_old"
                             fi
                             ;;
        trigger_mode)        options=("magic_word" "enter_key" "physical_button")
                             eval "$1=\"$(dialog_select "How to trigger Jarvis (before to say a command)" options[@] "${!1}")\""
                             ;;
        trigger_stt)         options=('snowboy' 'pocketsphinx' 'bing')
                             eval "$1=\"$(dialog_select "Which engine to use for the recognition of the hotword ($trigger)\nVisit http://openjarvis.com/content/stt\nRecommended: snowboy" options[@] "${!1}")\""
                             source stt_engines/$trigger_stt/main.sh
                             ;;
        tts_engine)          options=('svox_pico' 'google' 'espeak' 'osx_say')
                             recommended="$([ "$platform" = "osx" ] && echo 'osx_say' || echo 'svox_pico')"
                             eval "$1=\"$(dialog_select "Which engine to use for the speech synthesis\nVisit http://openjarvis.com/content/tts\nRecommended for your platform: $recommended" options[@] "${!1}")\""
                             source tts_engines/$tts_engine/main.sh
                             rm -f "$jv_cache_folder"/*.mp3 # remove cached voice
                             case "$tts_engine" in
                                 osx_say) configure "osx_say_voice";;
                             esac
                             ;;
        username)            eval "$1=\"$(dialog_input "How would you like to be called?" "${!1}" true)\"";;
        wit_server_access_token) eval "$1=\"$(dialog_input "Wit Server Access Token\nHow to get one: https://wit.ai/apps/new" "${!1}" true)\"";;
        *)                   jv_error "ERROR: Unknown configure $1";;
    esac
    return 0
}

wizard () {
    jv_check_updates
    
    # initiate directories
    mkdir -p config
    
    # initiate user commands & events if don't exist yet
    [ -f jarvis-commands ] || cp defaults/jarvis-commands-default jarvis-commands
    [ -f jarvis-events ] || cp defaults/jarvis-events-default jarvis-events
    
    dialog_msg "Hello, my name is JARVIS, nice to meet you"
    configure "language"

    [ "$language" != "en_EN" ] && dialog_msg <<EOM
Note: the installation & menus are only in English for the moment.
However, speech recognition and synthesis will be done in $language
EOM

    configure "username"
    
    configure "play_hw"
    configure "rec_hw"
    
    # if has mic
    if [ -n "$rec_hw" ]; then
        jv_auto_levels # adjust audio levels only if mic is present
        # || exit 1 # waiting to have more feedback on auto-adjust feature to make it mandatory
    
        configure "trigger_stt"
    
        if [ "$trigger_stt" = "snowboy" ]; then
            # use ' instead of " in dialog_msg
            dialog_msg <<EOM
You can now record and train your own hotword within Jarvis
Or you can immediately use the default universal hotword 'snowboy'
EOM
           trigger="${trigger:-snowboy}"
        fi
    else
        trigger_stt=false
    fi
    configure "trigger"
    
    # if has mic
    if [ -n "$rec_hw" ]; then
        configure "command_stt"
        if [ $trigger_stt = 'google' ] || [ $command_stt = 'google' ]; then
            configure "google_speech_api_key"
        fi
        if [ $trigger_stt = 'wit' ] || [ $command_stt = 'wit' ]; then
            configure "wit_server_access_token"
        fi
        if [ $trigger_stt = 'google' ] || [ $command_stt = 'google' ]; then
            configure "google_speech_api_key"
        fi
        if [ $trigger_stt = 'bing' ] || [ $command_stt = 'bing' ]; then
            configure "bing_speech_api_key"
        fi
    fi
    
    # if has speaker
    [ -n "$play_hw" ] && configure "tts_engine"
    
    configure "save"
    dialog_msg <<EOM
Congratulations! You can start using Jarvis
Select Plugins to check out community commands
Select Commands to add your own commands
Full Documentation & support available at:
http://openjarvis.com
EOM
}
