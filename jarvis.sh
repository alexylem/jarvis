#!/bin/bash
# +----------------------------------------+
# | JARVIS by Alexandre Mély - MIT license |
# | http://domotiquefacile.fr/jarvis       |
# +----------------------------------------+
flags='bc:ihjklmnp:qs:uvwx:z'
show_help () { cat <<EOF

    Usage: ${0##*/} [-$flags]

    Jarvis.sh is a lightweight configurable multi-lang jarvis-like bot
    Meant for home automation running on slow computer (ex: Raspberry Pi)
    It installs automatically speech recognition & synthesis engines of your choice

    Main options are now accessible through the application menu

    -b  run in background (no menu, continues after terminal is closed)
    -c  overrides conversation mode setting (true/false)
    -i  install (dependencies, pocketsphinx, setup)
    -h  display this help
    -j  output in JSON (for APIs)
    -k  directly start on keyboard mode
    -l  directly listen for one command (ex: launch from physical button)
    -m  mute mode (overrides settings)
    -n  directly start jarvis without menu
    -p  install plugin, ex: ${0##*/} -p https://github.com/alexylem/time
    -q  quit jarvis if running in background
    -s  just say something and exit, ex: ${0##*/} -s "hello world"
    -u  force update Jarvis and plugins (ex: use in cron)
    -v  troubleshooting mode
    -w  no colors in output
    -x  execute order, ex: ${0##*/} -x "switch on lights"

EOF
}

headline="NEW: Check out speech synthesis fun voices of Voxygen"

# Move to Jarvis directory
export jv_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$jv_dir" # needed now for git used in automatic update

shopt -s nocasematch # string comparison case insensitive
source utils/utils.sh # needed for wizard / platform error
source utils/store.sh # needed for plugin installation & store menu
source utils/update.sh # needed for update of Jarvis config

# Check platform compatibility
dependencies=(awk curl git iconv jq nano perl sed sox wget mpg123)
case "$OSTYPE" in
    linux*)     platform="linux"
                jv_arch="$(uname -m)"
                jv_os_name="$(cat /etc/*release | grep ^ID= | cut -f2 -d=)"
                jv_os_version="$(cat /etc/*release | grep ^VERSION_ID= | cut -f2 -d= | tr -d '"')"
                dependencies+=(alsamixer aplay arecord whiptail)
            	forder="/dev/shm/jarvis-order"
                ;;
    darwin*)    platform="osx"
                jv_arch="$(uname -m)"
                jv_os_name="$(sw_vers -productName)"
                jv_os_version="$(sw_vers -productVersion)"
                dependencies+=(osascript)
                forder="/tmp/jarvis-order"
                ;;
    *)          jv_error "ERROR: $OSTYPE is not a supported platform"
                exit 1;;
esac
source utils/dialog_$platform.sh # load default & user configuration

# Initiate files & directories
lockfile="/tmp/jarvis.lock"
mkdir -p config
mkdir -p plugins
audiofile="jarvis-record.wav"
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
                   'google_speech_api_key'
                   'language'
                   'language_model'
                   'trigger_mode'
                   'max_noise_duration_to_kill'
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
                   'voxygen_voice'
                   'wit_server_access_token')
    local hooks=(  'entering_cmd'
                   'exiting_cmd'
                   'program_startup'
                   'program_exit')
    case "$1" in
        bing_speech_api_key)   eval $1=`dialog_input "Bing Speech API Key\nHow to get one: http://domotiquefacile.fr/jarvis/content/bing" "${!1}"`;;
        check_updates)         options=('Always' 'Daily' 'Weekly' 'Never')
                               case "$(dialog_select "Check Updates when Jarvis starts up\nRecommended: Daily" options[@] "Daily")" in
                                   Always) eval $1=0;;
                                   Daily) eval $1=1;;
                                   Weekly) eval $1=7;;
                                   Never) eval $1=false;;
                               esac;;
        command_stt)           options=('bing' 'wit' 'snowboy' 'pocketsphinx')
                               eval $1=`dialog_select "Which engine to use for the recognition of commands\nVisit http://domotiquefacile.fr/jarvis/content/stt\nRecommended: bing" options[@] "${!1}"`
                               source stt_engines/$command_stt/main.sh;;
        conversation_mode)     eval $1=`dialog_yesno "Wait for another command after first executed" "${!1}"`;;
        dictionary)            eval $1=`dialog_input "PocketSphinx dictionary file" "${!1}"`;;
        google_speech_api_key) eval $1=`dialog_input "Google Speech API Key\nHow to get one: http://stackoverflow.com/a/26833337" "${!1}"`;;
        program_startup)       editor hooks/$1;;
        program_exit)          editor hooks/$1;;
        entering_cmd)          editor hooks/$1;;
        exiting_cmd)           editor hooks/$1;;
        language)              options=("en_GB" "es_ES" "fr_FR" "it_IT")
                               eval $1=`dialog_select "Language" options[@] "${!1}"`;;
        language_model)        eval $1=`dialog_input "PocketSphinx language model file" "${!1}"`;;
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
                    eval "$varname=\"`cat config/$varname`\""
                    not_installed=0
                fi
            done
            return $not_installed;;
        max_noise_duration_to_kill)     eval $1=`dialog_input "Max noise duration to kill" "${!1}"`;;
        min_noise_duration_to_start)    eval $1=`dialog_input "Min noise duration to start" "${!1}"`;;
        min_noise_perc_to_start)        eval $1=`dialog_input "Min noise durpercentageation to start" "${!1}"`;;
        min_silence_duration_to_stop)   eval $1=`dialog_input "Min silence duration to stop" "${!1}"`;;
        min_silence_level_to_stop)      eval $1=`dialog_input "Min silence level to stop" "${!1}"`;;
        osx_say_voice)
            local voices=(`/usr/bin/say -v ? | grep $language | awk '{print $1}'`)
            eval $1=`dialog_select "Select a voice for $language" voices[@] $osx_say_voice`;;
        phrase_failed)                  eval "$1=\"`dialog_input 'What to say if user command failed' "${!1}"`\"";;
        phrase_misunderstood)           eval "$1=\"`dialog_input 'What to say if order not recognized' "${!1}"`\"";;
        phrase_triggered)               eval "$1=\"`dialog_input 'What to say when magic word is heard' "${!1}"`\"";;
        phrase_welcome)                 eval "$1=\"`dialog_input 'What to say at program startup' "${!1}"`\"";;
        play_hw)
            while true; do
                dialog_msg "Checking audio output, make sure your speakers are on and press [Ok]"
                play "sounds/applause.wav"
                dialog_yesno "Did you hear something?" true && break
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
        pocketsphinxlog) eval $1=`dialog_input "File to store PocketSphinx logs" "${!1}"`;;
        rec_hw)
            rec_export=''
            while true; do
                dialog_yesno "Checking audio input, make sure your microphone is on, press [Yes] and say something.\nPress [No] if you don't have a micrphone." true || break
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
        save) for varname in "${variables[@]}"; do
                  #echo "DEBUG: saving ${!varname} into config/$varname"
                  echo "${!varname}" > config/$varname
              done;;
        separator)           eval $1=`dialog_input "Separator for multiple commands at once\nex: 'then' or empty to disable" "${!1}"`;;
        show_commands)       eval $1=`dialog_yesno "Show commands on startup and possible answers" "${!1}"`;;
        snowboy_sensitivity) eval $1=`dialog_input "Snowboy sensitivity from 0 (strict) to 1 (permissive)\nRecommended value: 0.5" "${!1}"`;;
        snowboy_token)       eval $1=$(dialog_input "Snowboy token\nGet one at: https://snowboy.kitt.ai" "${!1}");;
        tmp_folder)          eval $1=`dialog_input "Cache folder" "${!1}"`;;
        trigger)             eval "$1='`dialog_input \"Magic word to be said\" \"${!1}\"`'"
                             [ "$trigger_stt" = "snowboy" ] && stt_sb_train "$trigger"
                             ;;
        trigger_mode)        options=("magic_word" "enter_key" "physical_button")
                             eval $1=`dialog_select "How to trigger Jarvis (before to say a command)" options[@] "${!1}"`
                             ;;
        trigger_stt)         options=('snowboy' 'pocketsphinx' 'bing')
                             eval $1=`dialog_select "Which engine to use for the recognition of the trigger ($trigger)\nVisit http://domotiquefacile.fr/jarvis/content/stt\nRecommended: snowboy" options[@] "${!1}"`
                             source stt_engines/$trigger_stt/main.sh
                             ;;
        tts_engine) options=('svox_pico' 'google' 'espeak' 'osx_say' 'voxygen')
                    recommended=`[ "$platform" = "osx" ] && echo 'osx_say' || echo 'svox_pico'`
                    eval $1=`dialog_select "Which engine to use for the speech synthesis\nVisit http://domotiquefacile.fr/jarvis/content/tts\nRecommended for your platform: $recommended" options[@] "${!1}"`
                    source tts_engines/$tts_engine/main.sh;;
        username) eval $1=`dialog_input "How would you like to be called?" "${!1}"`;;
        voxygen_voice)       options=('Bruce' 'Jenny' 'Loic' 'Marion' 'Electra' 'Becool' 'Martha')
                             eval $1=`dialog_select "Voxygen Voice\nVisit https://www.voxygen.fr" options[@] "${!1}"`
                             rm -f /tmp/*.mp3 # remove cached voice
                             ;;
        wit_server_access_token) eval $1=`dialog_input "Wit Server Access Token\nHow to get one: https://wit.ai/apps/new" "${!1}"`;;
        *) jv_error "ERROR: Unknown configure $1";;
    esac
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
        jv_install ${missings[@]} || exit 1
    fi
    
    if [[ "$platform" == "linux" ]]; then
        if ! groups "$(whoami)" | grep -qw audio; then
            jv_warning "Your user should be part of audio group to list audio devices"
            jv_yesno "Would you like to add audio group to user $(whoami)?" && sudo usermod -a -G audio $(whoami)
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

    [ "$language" != "en_EN" ] && dialog_msg "Note: the installation & menus are only in English for the moment."

    configure "username"
    
    configure "play_hw"
    configure "rec_hw" # needed to train hotword
    
    configure "trigger_stt"
    
    if [ "$trigger_stt" = "snowboy" ]; then
        # use ' instead of " in dialog_msg
        dialog_msg <<EOM
You can now record and train your own hotword within Jarvis
Or you can immediately use the default universal hotword 'snowboy'
EOM
       trigger="snowboy"
    fi
    configure "trigger"
    
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
cat jarvis.log
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
            if [ -e $lockfile ] && kill -0 `cat $lockfile` 2>/dev/null; then
                echo "Jarvis is already running"
                echo "run ./jarvis.sh -q to stop it"
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
        s)	just_say=${OPTARG};;
        u)  jv_check_updates "./" true # force udpate
            jv_update_config # apply config updates
            jv_plugins_check_updates true # force udpate
            exit;;
        v)  verbose=true;;
        w)  unset _reset _red _orange _green _gray _blue _cyan _pink;;
        x)  just_execute="${OPTARG}";;
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
( jv_ga_send_hit & )

trigger_sanitized=$(jv_sanitize "$trigger")
[ -n "$conversation_mode_override" ] && conversation_mode=$conversation_mode_override
#update_commands
source jarvis-functions.sh
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
    if [ -e $lockfile ] && kill -0 `cat $lockfile` 2>/dev/null; then
        options=('Show Jarvis output' 'Stop Jarvis')
        case "`dialog_menu 'Jarvis is already running\nWhat would you like to do? (Cancel to let it run)' options[@]`" in
            Show*) cat jarvis.log;;
            Stop*) jv_kill_jarvis;;
        esac
        exit
    fi
    
    # check for updates
    if [ $check_updates != false ] && [ $just_listen = false ]; then
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
        for parameter in jv_version jv_arch jv_os_name jv_os_version language play_hw rec_hw speaker microphone trigger_stt command_stt tts_engine; do
            printf "%-20s %s \n" "$parameter" "${!parameter}"
        done
        echo -e "--------------------------------\n$_reset"
    fi
fi

source hooks/program_startup

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
    				action=`echo $action | sed 's/(\([0-9]\))/${BASH_REMATCH[\1]}/g'` # replace captures
    				$verbose && jv_debug "$> $action"
                    eval "$action" || say "$phrase_failed"
                    [[ "$action" == *jv_repeat_last_command* ]] || jv_last_command="${action//\$order/$order}"
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
    
    # welcome phrase
    [ $just_listen = false ] && [ ! -z "$phrase_welcome" ] && say "$phrase_welcome"
    
    # Display available commands to the user
    if $show_commands; then
        jv_display_commands
    else
        jv_debug "Use \"?\" to display possible commands"
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
            
            $quiet || ( $bypass && PLAY sounds/triggered.wav || PLAY sounds/listening.wav )
            
            while true; do
    			#$quiet || PLAY beep-high.wav

                $verbose && jv_debug "(listening...)"
                
                > $forder # empty $forder
                if $bypass; then
                    eval ${command_stt}_STT
                else
                    eval ${trigger_stt}_STT
                fi
    			#$verbose && PLAY beep-low.wav
                
    			order="$(cat $forder)"
    			if [ -z "$order" ]; then
                    printf '?'
                    PLAY sounds/error.wav
                    if [ $((++nb_failed)) -eq 3 ]; then
                        nb_failed=0
                        echo # new line
                        $verbose && jv_debug "DEBUG: 3 attempts failed, end of conversation"
                        PLAY sounds/timeout.wav
                        bypass=false
                        source hooks/exiting_cmd
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
                    bypass=true
                    echo $trigger # new line
                    source hooks/entering_cmd
                    say "$phrase_triggered"
                    continue 2
                fi
    			
    			#$verbose && PLAY beep-error.wav
    		done
    		#echo # new line
    	fi
    fi
    #was_in_conversation=$bypass
	[ -n "$order" ] && handle_orders "$order"
    order=""
    #if $was_in_conversation && ( ! $conversation_mode || ! $bypass ); then
    $conversation_mode || bypass=false
    $bypass || source hooks/exiting_cmd
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
