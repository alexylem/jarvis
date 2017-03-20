#!/bin/bash
# +----------------------------------------+
# | JARVIS by Alexandre Mély - MIT license |
# | http://domotiquefacile.fr/jarvis       |
# +----------------------------------------+
flags='bc:ihjklmnp:qrs:uvwx:z'
show_help () { cat <<EOF

    Usage: ${0##*/} [-$flags]

    Jarvis.sh is a lightweight configurable multi-lang voice assistant
    Meant for home automation running on slow computer (ex: Raspberry Pi)
    Installs automatically speech recognition & synthesis engines of your choice
    Highly extendable thanks to a wide catalog of community plugins

    Main options are now accessible through the application menu

    -b  run in background (no menu, continues after terminal is closed)
    -c  overrides conversation mode setting (true/false)
    -i  install and setup wizard
    -h  display this help
    -j  output in JSON (for APIs)
    -k  directly start in keyboard mode
    -l  directly listen for one command (ex: launch from physical button)
    -m  mute mode (overrides settings)
    -n  directly start jarvis without menu
    -p  install plugin, ex: ${0##*/} -p https://github.com/alexylem/time
    -q  quit jarvis if running in background
    -r  uninstall jarvis and its dependencies
    -s  just say something and exit, ex: ${0##*/} -s "hello world"
    -u  force update Jarvis and plugins (ex: use in cron)
    -v  troubleshooting mode
    -w  no colors in output
    -x  execute order, ex: ${0##*/} -x "switch on lights"

EOF
}

headline="NEW: Try snowboy recorder in Settings > Audio > Recorder"

# Move to Jarvis directory
export jv_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$jv_dir" # needed now for git used in automatic update

shopt -s nocasematch # string comparison case insensitive
source utils/utils.sh # needed for wizard / platform error
source utils/store.sh # needed for plugin installation & store menu
source utils/update.sh # needed for update of Jarvis config
source utils/audio.sh # needed for jv_auto_levels

# Check platform compatibility
dependencies=(awk curl git iconv jq nano perl sed sox wget mpg123)
case "$OSTYPE" in
    linux*)     platform="linux"
                jv_arch="$(uname -m)"
                jv_os_name="$(cat /etc/*release | grep ^ID= | cut -f2 -d=)"
                jv_os_version="$(cat /etc/*release | grep ^VERSION_ID= | cut -f2 -d= | tr -d '"')"
                dependencies+=(alsamixer aplay arecord whiptail)
            	jv_cache_folder="/dev/shm"
                ;;
    darwin*)    platform="osx"
                jv_arch="$(uname -m)"
                jv_os_name="$(sw_vers -productName)"
                jv_os_version="$(sw_vers -productVersion)"
                dependencies+=(osascript)
                jv_cache_folder="/tmp"
                ;;
    *)          jv_error "ERROR: $OSTYPE is not a supported platform"
                exit 1;;
esac
source utils/dialog_$platform.sh

# Initiate files & directories
mkdir -p config
mkdir -p plugins
lockfile="$jv_cache_folder/jarvis.lock"
audiofile="$jv_cache_folder/jarvis-record.wav"
forder="$jv_cache_folder/jarvis-order"
jv_say_queue="$jv_cache_folder/jarvis-say"
rm -f $audiofile # sometimes, when error, previous recording is played

# Only for retrocompatibility
#update_commands () {
    #remove heading "Yes?" system trigger response, now a phrase
    #grep -iv "^\*==" jarvis-commands > cmd.tmp; mv cmd.tmp jarvis-commands
    #remove traling "I don't understand" system command, now a phrase
    #grep -iv "^\*$trigger\*==" jarvis-commands > cmd.tmp; mv cmd.tmp jarvis-commands
#}

autoupdate () { # usage autoupdate 1 to show changelog
	printf "Updating..."
	git reset --hard HEAD >/dev/null # override any local change
	git pull -q &
    jv_spinner $!
	echo " " # removejv_spinner
    [ $1 ] || return
    #clear
    jv_success "Update completed"
    jv_warning "Recent changes:"
    head CHANGELOG.md #important to show if any important change user has to be aware of
    echo "[...] To see the full change log: more CHANGELOG.md"
}

# Configuration
configure () {
    local variables=('bing_speech_api_key'
                   'check_updates'
                   'command_stt'
                   'conversation_mode'
                   'dictionary'
                   'gain'
                   'google_speech_api_key'
                   'jv_branch'
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
                   'snowboy_sensitivity'
                   'snowboy_token'
                   'tmp_folder'
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
                   'stop_speaking')
    case "$1" in
        bing_speech_api_key)   eval "$1=\"$(dialog_input "Bing Speech API Key\nHow to get one: http://domotiquefacile.fr/jarvis/content/bing" "${!1}" true)\"";;
        check_updates)         options=('Always' 'Daily' 'Weekly' 'Never')
                               case "$(dialog_select "Check Updates when Jarvis starts up\nRecommended: Daily" options[@] "Daily")" in
                                   Always) check_updates=0;;
                                   Daily)  check_updates=1;;
                                   Weekly) check_updates=7;;
                                   Never)  check_updates=false;;
                               esac;;
        command_stt)           options=('bing' 'wit' 'snowboy' 'pocketsphinx')
                               eval "$1=\"$(dialog_select "Which engine to use for the recognition of commands\nVisit http://domotiquefacile.fr/jarvis/content/stt\nRecommended: bing" options[@] "${!1}")\""
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
        program_startup)       editor hooks/$1;;
        program_exit)          editor hooks/$1;;
        entering_cmd)          editor hooks/$1;;
        exiting_cmd)           editor hooks/$1;;
        start_listening)       editor hooks/$1;;
        stop_listening)        editor hooks/$1;;
        start_speaking)        editor hooks/$1;;
        stop_speaking)         editor hooks/$1;;
        language)              options=("de_DE (Deutsch)"
                                        "en_GB (English)"
                                        "es_ES (Español)"
                                        "fr_FR (Français)"
                                        "it_IT (Italiano)")
                               language="$(dialog_select "Language" options[@] "$language")"
                               language="${language% *}" # "fr_FR (Français)" => "fr_FR"
                               ;;
        language_model)        eval "$1=\"$(dialog_input "PocketSphinx language model file" "${!1}")\"";;
        load)
            source jarvis-config-default.sh
            [ -f jarvis-config.sh ] && source jarvis-config.sh # backward compatibility
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
            while true; do
                dialog_msg "Checking audio output, make sure your speakers are on and press [Ok]"
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
            done
            ;;
        pocketsphinxlog) eval "$1=\"$(dialog_input "File to store PocketSphinx logs" "${!1}")\"";;
        rec_hw) # returns 1 if no mic
            rec_export=''
            while true; do
                dialog_yesno "Checking audio input, make sure your microphone is on, press [Yes] and say something.\nPress [No] if you don't have a microphone." true >/dev/null || return 1
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
            done
            ;;
        recorder)            options=("snowboy" "sox")
                             eval "$1=\"$(dialog_select "Method to record commands from microphone" options[@] "${!1}")\""
                             ;;
        save) for varname in "${variables[@]}"; do
                  #echo "DEBUG: saving ${!varname} into config/$varname"
                  echo "${!varname}" > config/$varname
              done;;
        send_usage_stats)    eval "$1=\"$(dialog_yesno "Send anynomous usage statistics to help improving Jarvis" "${!1}")\"";;
        separator)           eval "$1=\"$(dialog_input "Separator for multiple commands at once\nex: 'then' or empty to disable" "${!1}")\"";;
        show_commands)       eval "$1=\"$(dialog_yesno "Show commands on startup and possible answers" "${!1}")\"";;
        snowboy_sensitivity) eval "$1=\"$(dialog_input "Snowboy sensitivity from 0 (strict) to 1 (permissive)\nRecommended value: 0.4" "${!1}")\"";;
        snowboy_token)       eval "$1=\"$(dialog_input "Snowboy token\nGet one at: https://snowboy.kitt.ai (in profile settings)" "${!1}" true)\"";;
        tmp_folder)          eval "$1=\"$(dialog_input "Cache folder" "${!1}")\"";;
        trigger)             eval "$1=\"$(dialog_input "How would you like your Jarvis to be called?\n(Hotword to be said before speaking commands)" "${!1}" true)\""
                             [ "$trigger_stt" = "snowboy" ] && stt_sb_train "$trigger"
                             ;;
        trigger_mode)        options=("magic_word" "enter_key" "physical_button")
                             eval "$1=\"$(dialog_select "How to trigger Jarvis (before to say a command)" options[@] "${!1}")\""
                             ;;
        trigger_stt)         options=('snowboy' 'pocketsphinx' 'bing')
                             eval "$1=\"$(dialog_select "Which engine to use for the recognition of the hotword ($trigger)\nVisit http://domotiquefacile.fr/jarvis/content/stt\nRecommended: snowboy" options[@] "${!1}")\""
                             source stt_engines/$trigger_stt/main.sh
                             ;;
        tts_engine)          options=('svox_pico' 'google' 'espeak' 'osx_say') # 'voxygen'
                             recommended="$([ "$platform" = "osx" ] && echo 'osx_say' || echo 'svox_pico')"
                             eval "$1=\"$(dialog_select "Which engine to use for the speech synthesis\nVisit http://domotiquefacile.fr/jarvis/content/tts\nRecommended for your platform: $recommended" options[@] "${!1}")\""
                             source tts_engines/$tts_engine/main.sh
                             rm -f "$jv_cache_folder"/*.mp3 # remove cached voice
                             case "$tts_engine" in
                                 osx_say) configure "osx_say_voice";;
                                 #voxygen) configure "voxygen_voice";;
                             esac
                             ;;
        username)            eval "$1=\"$(dialog_input "How would you like to be called?" "${!1}" true)\"";;
#        voxygen_voice)       case "$language" in
#                                de_DE) options=('Matthias');;
#                                es_ES) options=('Martha');;
#                                fr_FR) options=('Loic' 'Philippe' 'Marion' 'Electra' 'Becool');;
#                                it_IT) options=('Sonia');;
#                                en_GB) options=('Bruce' 'Jenny');;
#                                *)     options=();;
#                             esac
#                             eval "$1=\"$(dialog_select "Voxygen $language Voices\nVisit https://www.voxygen.fr to test them" options[@] "${!1}")\""
#                             rm -f "$jv_cache_folder"/*.mp3 # remove cached voice
#                             ;;
        wit_server_access_token) eval "$1=\"$(dialog_input "Wit Server Access Token\nHow to get one: https://wit.ai/apps/new" "${!1}" true)\"";;
        *)                   jv_error "ERROR: Unknown configure $1";;
    esac
    return 0
}

check_dependencies () {
    missings=()
    for i in "${dependencies[@]}"; do
        hash $i 2>/dev/null || missings+=($i)
    done
    if [ ${#missings[@]} -gt 0 ]; then
        jv_warning "You must install missing dependencies before going further"
        for missing in "${missings[@]}"; do
            echo "$missing: Not found"
        done
        jv_yesno "Attempt to automatically install the above packages?" || exit 1
        jv_update # split jv_update and jv_install to make overall jarvis installation faster
        jv_install ${missings[@]} || exit 1
    fi
    
    if [[ "$platform" == "linux" ]]; then
        if ! groups "$(whoami)" | grep -qw audio; then
            jv_warning "Your user should be part of audio group to list audio devices"
            jv_yesno "Would you like to add audio group to user $USER?" || exit 1
            sudo usermod -a -G audio $USER # add audio group to user
            jv_warning "Please logout and login for new group permissions to take effect, then restart Jarvis"
            exit
        fi
    fi
}

wizard () {
    jv_check_updates
    jv_update_config
    
    # initiate user commands & events if don't exist yet
    [ -f jarvis-commands ] || cp jarvis-commands-default jarvis-commands
    [ -f jarvis-events ] || cp jarvis-events-default jarvis-events
    
    dialog_msg "Hello, my name is JARVIS, nice to meet you"
    configure "language"

    [ "$language" != "en_EN" ] && dialog_msg <<EOM
Note: the installation & menus are only in English for the moment.
However, speech recognition and synthesis will be done in $language
EOM

    configure "username"
    
    configure "play_hw"
    # rec_hw needed to train hotword 
    local has_mic=false
    configure "rec_hw" && has_mic=true  # returns 1 if no mic
    
    if $has_mic; then
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
    
    if $has_mic; then
        configure "command_stt"
        if [ $trigger_stt = 'google' ] || [ $command_stt = 'google' ]; then
            configure "google_speech_api_key"
        fi
        if [ $trigger_stt = 'wit' ] || [ $command_stt = 'wit' ]; then
            configure "wit_server_access_token"
        fi
        if [ $trigger_stt = 'bing' ] || [ $command_stt = 'bing' ]; then
            configure "bing_speech_api_key"
        fi
    fi
    
    configure "tts_engine"
    
    configure "save"
    dialog_msg <<EOM
Congratulations! You can start using Jarvis
Select Plugins to check out community commands
Select Commands to add your own commands
Full Documentation & support available at:
http://domotiquefacile.fr/jarvis
EOM
}

jv_start_in_background () {
    nohup ./jarvis.sh -n 2>&1 | jv_add_timestamps >> jarvis.log &
    cat <<EOM
Jarvis has been launched in background

To view Jarvis output:
./jarvis.sh and select "View output"
To check if jarvis is running:
pgrep -lf jarvis.sh
To stop Jarvis:
./jarvis.sh and select "Stop Jarvis"

You can now close this terminal
EOM
}

# default flags, use options to change see jarvis.sh -h
quiet=false
verbose=false
keyboard=false
just_say=false
just_listen=false
just_execute=false
no_menu=false
jv_json=false
while getopts ":$flags" o; do
    case "${o}" in
		b)  # Check if Jarvis is already running in background
            if jv_is_started; then
                jv_error "Jarvis is already running"
                jv_warning "run ./jarvis.sh -q to stop it"
                exit 1
            fi
            jv_start_in_background
            exit;;
        c)  conversation_mode_override=${OPTARG};;
        i)  check_dependencies
            configure "load"
            wizard
            exit;;
        h)  show_help
            exit;;
        j)  jv_json=true
            printf "[";;
	    k)  keyboard=true
	        no_menu=true;;
        l)  just_listen=true
            no_menu=true;;
        m)  quiet=true;;
        n)  no_menu=true;;
		p)  store_install_plugin "${OPTARG}"
            exit;;
        q)  jv_kill_jarvis
            exit $?;;
        r)  source uninstall.sh
            exit $?;;
        s)	just_say=${OPTARG}
            jv_api=true;;
        u)  jv_check_updates "./" true # force udpate
            jv_update_config # apply config updates
            jv_plugins_check_updates true # force udpate
            touch config/last_update_check
            exit;;
        v)  verbose=true;;
        w)  unset _reset _red _orange _green _gray _blue _cyan _pink;;
        x)  just_execute="${OPTARG}"
            jv_api=true;;
        z)  jv_build
            exit;;
        *)	echo "Usage: $0 [-$flags]" 1>&2; exit 1;;
    esac
done

# Check not ran as root
if [ "$EUID" -eq 0 ]; then
    jv_error "ERROR: Jarvis must not be used as root"
    exit 1
fi

# check dependencies
check_dependencies
# load user settings if exist else launch install wizard
configure "load" || wizard
# send google analytics hit
$send_usage_stats && ( jv_ga_send_hit & )

trigger_sanitized=$(jv_sanitize "$trigger")
[ -n "$conversation_mode_override" ] && conversation_mode=$conversation_mode_override
source recorders/$recorder/main.sh
source stt_engines/$trigger_stt/main.sh
source stt_engines/$command_stt/main.sh
source tts_engines/$tts_engine/main.sh

if ( [ "$play_hw" != "false" ] || [ "$rec_hw" != "false" ] ) && [ ! -f ~/.asoundrc ]; then
    update_alsa $play_hw $rec_hw  # retro compatibility
    dialog_msg<<EOM
JARVIS has created .asoundrc in your homefolder
YOU MUST REBOOT YOUR SYSTEM TO TAKE IT INTO ACCOUNT
EOM
    echo "Please reboot: sudo reboot"
    exit
fi

# if -s argument provided, just say it & exit (used in jarvis-events)
if [[ "$just_say" != false ]]; then
    say "$just_say"
    jv_exit # to properly end JSON if -j flag used
fi

if [ "$just_execute" == false ]; then
    # Check if Jarvis is already running in background
    if jv_is_started; then
        options=('Show Jarvis output' 'Stop Jarvis')
        case "$(dialog_menu 'Jarvis is already running\nWhat would you like to do? (Cancel to let it run)' options[@])" in
            Show*) tail -f jarvis.log;;
            Stop*) jv_kill_jarvis;;
        esac
        exit
    fi
    
    # check for updates
    if [ $check_updates != false ] && [ $no_menu = false ]; then
        if [ "$(find config/last_update_check -mtime -$check_updates 2>/dev/null | wc -l)" -eq 0 ]; then
            jv_jarvis_updated=false
            jv_check_updates
            jv_update_config # apply config upates
            jv_plugins_check_updates
            touch config/last_update_check
            if $jv_jarvis_updated; then
                echo "Please restart Jarvis"
                exit
            fi
        fi
    fi
    
    # main menu
    source utils/menu.sh
    jv_main_menu

    # Dump config in troubleshooting mode
    if [ $verbose = true ]; then
        if [ "$play_hw" != "false" ]; then
            play_path="/proc/asound/card${play_hw:3:1}"
            [ -e "$play_path/usbid" ] && speaker=$(lsusb -d $(cat "$play_path/usbid") | cut -c 34-) || speaker=$(cat "$play_path/id")
        else
            speaker="Default"
        fi
        [ "$rec_hw" != "false" ] && microphone=$(lsusb -d $(cat /proc/asound/card${rec_hw:3:1}/usbid) | cut -c 34-) || microphone="Default"
        echo -e "$_gray\n------------ Config ------------"
        for parameter in jv_branch jv_version jv_arch jv_os_name jv_os_version language play_hw rec_hw speaker microphone recorder trigger_stt command_stt tts_engine; do
            printf "%-20s %s \n" "$parameter" "${!parameter}"
        done
        echo -e "--------------------------------\n$_reset"
    fi
fi

# Include installed plugins
shopt -s nullglob
for f in plugins/*/config.sh; do source $f; done # plugin configuration
for f in plugins/*/functions.sh; do source $f; done # plugin functions
for f in plugins/*/${language:0:2}/functions.sh; do source $f; done # plugin language specific functions
shopt -u nullglob
jv_plugins_order_rebuild
jv_get_commands () {
    grep -v "^#" jarvis-commands
    while read; do
        cat plugins/$REPLY/${language:0:2}/commands 2>/dev/null
    done <plugins_order.txt
}

# run startup hooks after plugin load
jv_hook "program_startup"

# Public: handle an order and execute corresponding command
# 
# $1 - order to recognize
#
# Usage
#
#   jv_handle_order "what time is it?"
jv_handle_order() {
    local order=$1
    local sanitized="$(jv_sanitize "$order")"
	local check_indented=false
    
    if [ "$order" = "?" ]; then
        jv_display_commands
        return
    fi
    
    if ! $jv_possible_answers; then
        #jv_debug "no nested answers, resetting commands..."
        commands="$(jv_get_commands)"
    fi
    
    while read line; do
        if $check_indented; then
            #jv_debug "checking if possible answers in: $line"
            if [ "${line:0:1}" = ">" ]; then
                [ -z "$commands" ] && commands="${line:1}" || commands+=$'\n'${line:1}
                jv_possible_answers=true
            else
                # no [more] nested answers
                break
            fi
        else
            [ "${line:0:1}" = ">" ] && continue #https://github.com/alexylem/jarvis/issues/305
            patterns=${line%==*} # *HELLO*|*GOOD*MORNING*==say Hi => *HELLO*|*GOOD*MORNING*
    		IFS='|' read -ra ARR <<< "$patterns" # *HELLO*|*GOOD*MORNING* => [*HELLO*, *GOOD*MORNING*]
    		for pattern in "${ARR[@]}"; do # *HELLO*
    			regex="^${pattern//'*'/.*}$" # .*HELLO.*
                if [[ $sanitized =~ $regex ]]; then # HELLO THERE =~ .*HELLO.*
                    action=${line#*==} # *HELLO*|*GOOD*MORNING*==say Hi => say Hi
    				action="$(echo $action | sed 's/(\([0-9]\))/${BASH_REMATCH[\1]}/g')" # replace captures
    				[[ "$action" == *jv_repeat_last_command* ]] || jv_last_command="${action//\$order/$order}"
                    $verbose && jv_debug "$> $action"
                    eval "$action" || say "$phrase_failed"
                    check_indented=true
                    commands=""
                    jv_possible_answers=false
                    break
    			fi
    		done
        fi
	done <<< "${commands//\\/\\\\}" # https://github.com/alexylem/jarvis/issues/147
    if ! $check_indented; then
        say "$phrase_misunderstood: $order"
    #elif [ -z "$commands" ]; then
    #    commands="$(jv_get_commands)"
    fi
    if $show_commands && $jv_possible_answers; then
        # display possible direct answers
        # jv_info "possible answers:"
        jv_debug "$(echo "$commands" | grep "^[^>]" | cut -d '=' -f 1 | pr -3 -l1 -t)"
    fi
}

handle_orders() {
    if [ -z "$separator" ]; then
        jv_handle_order "$1"
    else
        orders=$(echo "$1" | awk "BEGIN {FS=\" `echo $separator` \"} {for(i=1;i<=NF;i++)print \$i}")
        while read order; do
            jv_handle_order "$order"
        done <<< "$orders"
    fi
}

# if -x argument provided, just handle order & exit (used in jarvis-events)
#if [[ "$just_execute" != false ]]; then
#	jv_handle_order "$just_execute"
#	jv_exit
#fi

# only if not just execute to avoid erase lockfile from API
if [ "$just_execute" = false ]; then
    # trap Ctrl+C or kill
    trap "jv_exit" INT TERM
    
    # save pid in lockfile for proper kill
    echo $$ > $lockfile
    
    # start say service
    if ! $jv_api; then
        [ -p $jv_say_queue ] || mkfifo $jv_say_queue # create pipe if not exists
        source utils/say.sh &
    fi
    
    # welcome phrase
    [ $just_listen = false ] && [ ! -z "$phrase_welcome" ] && say "$phrase_welcome"
    
    # Display available commands to the user
    if $show_commands; then
        jv_display_commands
    else
        jv_debug "Use \"?\" to display possible commands (in keyboard mode)"
    fi
    
    bypass=$just_listen
else # just execute an order
    order="$just_execute"
    
    if [ -f /tmp/jarvis-possible-answers ]; then
        # there are possible answers from previous json conversation (nested commmands)
        commands="$(cat /tmp/jarvis-possible-answers)"
        # remove file to avoid future issues
        rm /tmp/jarvis-possible-answers
        # indicate there are possible answers not to reset commands
        jv_possible_answers=true
    fi
    # no need to say Jarvis if just execute
    bypass=true
fi

while true; do
	if [ -z "$order" ]; then
        if [ $keyboard = true ]; then
            bypass=true
    		printf "$_cyan$username$_reset: "
            read order
    	else
    		if [ "$trigger_mode" = "enter_key" ]; then
    			bypass=true
    			read -p "Press [Enter] to start voice command"
    		fi
    		! $bypass && echo -e "$_pink$trigger$_reset: Waiting to hear '$trigger'"
    		printf "$_cyan$username$_reset: "
            
            $quiet || ( $bypass && jv_play sounds/triggered.wav || jv_play sounds/listening.wav )
            
            nb_failed=0
            while true; do
    			#$quiet || jv_play beep-high.wav
                
                $verbose && jv_debug "(listening...)"
                > $forder # empty $forder
                if $bypass; then
                    eval ${command_stt}_STT
                else
                    eval ${trigger_stt}_STT
                fi
                retcode=$?
                (( $retcode )) && error=true || error=false
                
                # if there was no error doing speech to text
                if ! $error; then
                    # retrieve transcribed speech
                    order="$(cat $forder)"
                    # check if it is empty
                    if [ -z "$order" ]; then
                        printf '?'
                        error=true
                    fi
                fi
                
    			if $error; then
                    finish=false
                    if [ $retcode -eq 124 ]; then # timeout
                        sleep 1 # BUG here despite timeout mic still busy can't rec again...
                        $verbose && jv_debug "DEBUG: timeout, end of conversation" || jv_debug '(timeout)'
                        finish=true
                    else
                        jv_play sounds/error.wav
                        if [  $((++nb_failed)) -eq 3 ]; then
                            $verbose && jv_debug "DEBUG: 3 attempts failed, end of conversation"
                            finish=true
                            echo # new line
                        fi
                    fi
                    if $finish; then
                        jv_play sounds/timeout.wav
                        bypass=false
                        jv_hook "exiting_cmd"
                        commands="$(jv_get_commands)" # in case we were in nested commands
                        $just_listen && jv_exit
                        continue 2
                    fi
                    continue
                fi
                
    			if $bypass; then
                    echo "$order" # printf fails when order has %
                    break
                elif [[ "$order" == *$trigger_sanitized* ]]; then
                    order=""
                    echo $trigger # new line
                    bypass=true
                    jv_hook "entering_cmd"
                    [ -n "$phrase_triggered" ] && say "$phrase_triggered"
                    continue 2
                fi
    			
    			#$verbose && jv_play beep-error.wav
    		done
    		#echo # new line
    	fi
    fi
    #was_in_conversation=$bypass
	[ -n "$order" ] && handle_orders "$order"
    order=""
    #if $was_in_conversation && ( ! $conversation_mode || ! $bypass ); then
    if ! $jv_possible_answers && ! $conversation_mode; then # jarvis-api#6
        bypass=false
    fi
    $bypass || jv_hook "exiting_cmd"
    #fi
    $just_listen && [ $bypass = false ] && jv_exit
    if [ "$just_execute" != false ]; then
        if $jv_possible_answers; then
            if $jv_json; then
                # if in nested commands, save possible answer for next json call
                echo -e "$commands" > /tmp/jarvis-possible-answers
                jv_exit
            fi
        else # just execute but not pending answer, finished
            jv_exit
        fi
    fi
done
