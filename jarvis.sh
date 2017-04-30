#!/bin/bash
# +----------------------------------------+
# | JARVIS by Alexandre Mély - MIT license |
# | http://domotiquefacile.fr/jarvis       |
# +----------------------------------------+
flags='bc:ihjklmnp:qrs:uvwx:z'
jv_show_help () { cat <<EOF

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
    -p  install plugin, ex: ${0##*/} -p https://github.com/alexylem/jarvis-time
    -q  quit jarvis if running in background
    -r  uninstall jarvis and its dependencies
    -s  just say something and exit, ex: ${0##*/} -s "hello world"
    -u  force update Jarvis and plugins (ex: use in cron)
    -v  troubleshooting mode
    -w  no colors in output
    -x  execute order, ex: ${0##*/} -x "switch on lights"

EOF
}

headline="NEW: Adjust playback speed in Settings > Audio > Tempo"

# Move to Jarvis directory
export jv_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # why export?
cd "$jv_dir" # needed now for git used in automatic update

shopt -s nocasematch # string comparison case insensitive
source utils/utils.sh # needed for wizard / platform error
source utils/store.sh # needed for plugin installation & store menu
source utils/update.sh # needed for update of Jarvis config
source utils/audio.sh # needed for jv_auto_levels
source utils/configure.sh # needed to configure jarvis

# Check platform compatibility
dependencies=(awk curl git iconv jq nano perl sed sox wget)
case "$OSTYPE" in
    linux*)     platform="linux"
                jv_arch="$(uname -m)"
                jv_os_name="$(cat /etc/*release | grep ^ID= | cut -f2 -d=)"
                jv_os_version="$(cat /etc/*release | grep ^VERSION_ID= | cut -f2 -d= | tr -d '"')"
                dependencies+=(alsamixer aplay arecord whiptail libsox-fmt-mp3)
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
source utils/utils_$platform.sh

# Initiate files & directories
lockfile="$jv_cache_folder/jarvis.lock"
audiofile="$jv_cache_folder/jarvis-record.wav"
forder="$jv_cache_folder/jarvis-order"
jv_say_queue="$jv_cache_folder/jarvis-say"
jv_store_file="$jv_cache_folder/jarvis-store.json"
rm -f $audiofile # sometimes, when error, previous recording is played
if [ ! -d "plugins_installed" ]; then
    if [ -d "plugins" ]; then # retrocompatibility
        mv plugins plugins_installed 2>/dev/null
    else
        mkdir "plugins_installed"
    fi
fi
if [ ! -d "plugins_enabled" ]; then
    mkdir plugins_enabled
    for plugin in $(ls plugins_installed); do
        jv_plugin_enable "$plugin"
    done
fi

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
        h)  jv_show_help
            exit;;
        i)  jv_check_dependencies
            configure "load"
            wizard
            exit;;
        j)  jv_json=true
            printf "[";;
	    k)  keyboard=true
	        no_menu=true;;
        l)  jv_api=true
            if jv_is_started; then
                kill -$jv_sig_listen $(cat $lockfile)
                jv_success "Ok"
                jv_exit # to properly end JSON if -j flag used
            fi
            just_listen=true
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
        u)  configure "load" #498 
            jv_check_updates "./" true # force udpate
            source utils/update.sh # apply config updates
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
jv_check_dependencies
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

if [ "$jv_api" == false ]; then
    # Check if Jarvis is already running in background
    if jv_is_started; then
        options=('Show Jarvis output'
                 'Listen now for a command'
                 'Pause / Resume'
                 'Stop Jarvis')
        case "$(dialog_menu 'Jarvis is already running\nWhat would you like to do? (Cancel to let it run)' options[@])" in
            Show*)   tail -f jarvis.log;;
            Listen*) kill -$jv_sig_listen $(cat $lockfile);;
            Pause*)  kill -$jv_sig_pause $(cat $lockfile);;
            Stop*)   jv_kill_jarvis;;
        esac
        exit
    fi
    
    # check for updates
    if [ $check_updates != false ] && [ $no_menu = false ]; then
        if [ "$(find config/last_update_check -mtime -$check_updates 2>/dev/null | wc -l)" -eq 0 ]; then
            jv_check_updates
            source utils/update.sh # apply config upates
            jv_plugins_check_updates
            touch config/last_update_check
            if $jv_jarvis_updated; then
                echo "Please restart Jarvis"
                exit
            fi
        fi
    fi
    
    # main menu
    if ! $no_menu; then
        source utils/menu.sh
        jv_menu_main
    fi

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

# Include user functions before just_say because user start/stop_speaking may use them
[ -f my-functions.sh ] || cp defaults/my-functions-default.sh my-functions.sh
source my-functions.sh #470

# Include installed plugins before just_say because plugin start/stop_speaking hooks
shopt -s nullglob
for f in plugins_enabled/*/config.sh; do source $f; done # plugin configuration
for f in plugins_enabled/*/functions.sh; do source $f; done # plugin functions
for f in plugins_enabled/*/${language:0:2}/functions.sh; do source $f; done # plugin language specific functions
shopt -u nullglob

# if -s argument provided, just say it & exit (used in jarvis-events)
if [ "$just_say" != false ]; then
    say "$just_say"
    jv_exit # to properly end JSON if -j flag used
fi

jv_plugins_order_rebuild # why here? in case plugin is manually added/delete?

# run startup hooks after plugin load
$jv_api || jv_hook "program_startup" # don't trigger program_* from api calls

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

# only if not just execute to avoid erase lockfile from API
if [ "$just_execute" = false ]; then
    # trap Ctrl+C or kill
    trap "jv_exit" INT TERM
    trap "jv_pause_resume" $jv_sig_pause
    trap ":" $jv_sig_listen
    
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
    
    if [ -f $jv_cache_folder/jarvis-possible-answers ]; then
        # there are possible answers from previous json conversation (nested commmands)
        commands="$(cat $jv_cache_folder/jarvis-possible-answers)"
        # remove file to avoid future issues
        rm $jv_cache_folder/jarvis-possible-answers
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
                #jv_debug "retcode=$retcode"
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
                
                if $jv_is_paused; then
                    echo "paused"
                    $verbose && jv_debug "to resume, run: ./jarvis.sh and select Resume"
                    wait # until signal
                    continue 2
                fi
                
    			if $error; then
                    finish=false
                    if [ $retcode -eq 124 ]; then # timeout
                        sleep 1 # BUG here despite timeout mic still busy can't rec again...
                        $verbose && jv_debug "DEBUG: timeout, end of conversation" || jv_debug '(timeout)'
                        jv_hook "listening_timeout"
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
                echo -e "$commands" > $jv_cache_folder/jarvis-possible-answers
                jv_exit
            fi
        else # just execute but not pending answer, finished
            jv_exit
        fi
    fi
done
