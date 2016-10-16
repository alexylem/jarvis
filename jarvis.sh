#!/bin/bash
# +----------------------------------------+
# | JARVIS by Alexandre Mély - MIT license |
# | http://domotiquefacile.fr/jarvis       |
# +----------------------------------------+
flags='bc:ihlnp:s:x:z'
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
    -l  directly listen for one command (ex: launch from physical button)
    -n  directly start jarvis without menu
    -p  install plugin, ex: ${0##*/} -p https://github.com/alexylem/time
    -s  just say something and exit, ex: ${0##*/} -s "hello world"
    -x  execute order, ex: ${0##*/} -x "switch on lights"

EOF
}

headline="NEW! Visit the WebStore: http://domotiquefacile.fr/jarvis"

# Move to Jarvis directory
DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" # needed now for git used in automatic update

shopt -s nocasematch # string comparison case insensitive
source utils/utils.sh # needed for wizard / platform error
source utils/store.sh # needed for plugin installation & store menu

# Check platform compatibility
dependencies=(awk curl git iconv jq nano perl sed sox wget)
if [ "$(uname)" == "Darwin" ]; then
	platform="osx"
	dependencies+=(osascript)
    install_cmd="brew install"
	forder="/tmp/jarvis-order"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
	platform="linux"
	dependencies+=(alsamixer aplay arecord mpg123 whiptail)
    install_cmd="sudo apt-get install -y"
	forder="/dev/shm/jarvis-order"
else
	my_error "ERROR: Unsupported platform"; exit 1
fi
source utils/dialog_$platform.sh # load default & user configuration

# Check not ran as root
if [ "$EUID" -eq 0 ]; then
    my_error "ERROR: Jarvis must not be used as root"
    exit 1
fi

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
    my_success "Update completed"
    my_warning "Recent changes:"
    head CHANGELOG.md #important to show if any important change user has to be aware of
    echo "[...] To see the full change log: more CHANGELOG.md"
}

checkupdates () {
    [ -f jarvis-commands ] || cp jarvis-commands-default jarvis-commands
    [ -f jarvis-events ] || cp jarvis-events-default jarvis-events
	printf "Checking for updates..."
	git fetch origin -q &
jv_spinner $!
	case `git rev-list HEAD...origin/master --count || echo e` in
		"e") echo -e "[\033[31mError\033[0m]";;
		"0") echo -e "[\033[32mUp-to-date\033[0m]";;
		*)	echo -e "[\033[33mNew version available\033[0m]"
            changes=$(git fetch -q 2>&1 && git log HEAD..origin/master --oneline --format="- %s (%ar)" | head -5)
            if dialog_yesno "A new version of JARVIS is available, recent changes:\n$changes\n\nWould you like to update?" false >/dev/null; then
				autoupdate 1 # hasjv_spinner inside
				#dialog_msg "Please restart JARVIS"
				exit
			fi
			;;
	esac
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
                   'snowboy_sensitivity'
                   'tmp_folder'
                   'trigger'
                   'trigger_stt'
                   'trigger_mode'
                   'tts_engine'
                   'username'
                   'wit_server_access_token')
    local hooks=(  'entering_cmd'
                   'exiting_cmd'
                   'program_startup'
                   'program_exit')
    case "$1" in
        bing_speech_api_key)   eval $1=`dialog_input "Bing Speech API Key\nHow to get one: http://domotiquefacile.fr/jarvis/content/bing" "${!1}"`;;
        check_updates)         eval $1=`dialog_yesno "Check Updates when Jarvis starts up (recommended)" "${!1}"`;;
        command_stt)           options=('bing' 'wit' 'pocketsphinx')
                               eval $1=`dialog_select "Which engine to use for the recognition of commands\nVisit http://domotiquefacile.fr/jarvis/content/stt\nRecommended: bing (google has been removed because deprecated)" options[@] "${!1}"`
                               source stt_engines/$command_stt/main.sh;;
        conversation_mode)     eval $1=`dialog_yesno "Wait for another command after first executed" "${!1}"`;;
        dictionary)            eval $1=`dialog_input "PocketSphinx dictionary file" "${!1}"`;;
        google_speech_api_key) eval $1=`dialog_input "Google Speech API Key\nHow to get one: http://stackoverflow.com/a/26833337" "${!1}"`;;
        program_startup)       editor hooks/$1;;
        program_exit)          editor hooks/$1;;
        entering_cmd)          editor hooks/$1;;
        exiting_cmd)           editor hooks/$1;;
        language)              options=("en_GB" "es_ES" "fr_FR")
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
                my_warning "Selection of the speaker device"
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
                dialog_msg "Checking audio input, make sure your microphone is on, press [Ok] and say something"
                clear
                rec $audiofile trim 0 3
                if [ $? -eq 0 ]; then
                    play $audiofile
                    dialog_yesno "Did you hear yourself?" true >/dev/null && break
                fi
                my_warning "Selection of the microphone device"
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
        snowboy_sensitivity) eval $1=`dialog_input "Snowboy sensitivity from 0 (strict) to 1 (permissive)\nRecommended value: 0.5" "${!1}"`;;
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
                             if [ "$trigger_stt" = "snowboy" ]; then
                                 # use ' instead of " in dialog_msg
                                 dialog_msg <<EOM
You can now record and train your own hotword within Jarvis
Or you can immediately use the default universal hotword 'snowboy'
EOM
                                trigger="snowboy"
                                configure "trigger"
                             fi
                             source stt_engines/$trigger_stt/main.sh
                             ;;
        tts_engine) options=('svox_pico' 'google' 'espeak' 'osx_say')
                    recommended=`[ "$platform" = "osx" ] && echo 'osx_say' || echo 'svox_pico'`
                    eval $1=`dialog_select "Which engine to use for the speech synthesis\nVisit http://domotiquefacile.fr/jarvis/content/tts\nRecommended for your platform: $recommended" options[@] "${!1}"`
                    source tts_engines/$tts_engine/main.sh;;
        username) eval $1=`dialog_input "How would you like to be called?" "${!1}"`;;
        wit_server_access_token) eval $1=`dialog_input "Wit Server Access Token\nHow to get one: https://wit.ai/apps/new" "${!1}"`;;
        *) my_error "ERROR: Unknown configure $1";;
    esac
}

check_dependencies () {
    missings=()
    for i in "${dependencies[@]}"; do
        hash $i 2>/dev/null || missings+=($i)
    done
    if [ ${#missings[@]} -gt 0 ]; then
        my_error "ERROR: You must install missing dependencies before going further"
        for missing in "${missings[@]}"; do
            echo "$missing: Not found"
        done
        my_success "HELP: $install_cmd ${missing[@]}"
        exit 1
    fi
}

wizard () {
    checkupdates
    
    dialog_msg "Hello, my name is JARVIS, nice to meet you"
    configure "language"

    [ "$language" != "en_EN" ] && dialog_msg "Note: the installation & menus are only in English for the moment."

    configure "username"
    configure "trigger_stt"
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

    configure "play_hw"
    configure "rec_hw"

    configure "save"
    dialog_msg "Setup wizard completed."
}

start_in_background () {
    ./jarvis.sh -n > jarvis.log 2>&1 &
    disown
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
while getopts ":$flags" o; do
    case "${o}" in
		b)  # Check if Jarvis is already running in background
            if [ -e $lockfile ] && kill -0 `cat $lockfile` 2>/dev/null; then
                echo "Jarvis is already running"
                echo "run ./jarvis.sh to detect and stop it"
                exit 1
            fi
            start_in_background
            exit;;
        c)  conversation_mode_override=${OPTARG};;
        i)  configure "load"
            wizard
            exit;;
        h)  show_help
            exit;;
        l)  just_listen=true
            no_menu=true;;
        n)  no_menu=true;;
		p)  store_install_plugin "${OPTARG}"
            exit;;
        s)	just_say=${OPTARG};;
        x)  just_execute="${OPTARG}";;
        z)  jv_build
            exit;;
        *)	echo "Usage: $0 [-$flags]" 1>&2; exit 1;;
    esac
done

check_dependencies
configure "load" || wizard
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
	exit
fi

# Include installed plugins
shopt -s nullglob
for f in plugins/*/config.sh; do source $f; done
for f in plugins/*/${language:0:2}/functions.sh; do source $f; done
shopt -u nullglob
commands=`cat jarvis-commands plugins/*/${language:0:2}/commands 2>/dev/null`
handle_order() {
    local order=$1
    local sanitized="$(jv_sanitize "$order")"
	local check_indented=false
    while read line; do
        if $check_indented; then
            #echo "checking if possible answers in: $line"
            if [ "${line:0:1}" = ">" ]; then
                newline=$'\n'
                commands="$commands$newline${line:1}"
            else
                if [ -z "$commands" ]; then
                    commands=`cat jarvis-commands plugins/*/${language:0:2}/commands 2>/dev/null`
                fi
                #echo "$commands"
                check_indented=false
                return
            fi
        else
            patterns=${line%==*} # *HELLO*|*GOOD*MORNING*==say Hi => *HELLO*|*GOOD*MORNING*
    		IFS='|' read -ra ARR <<< "$patterns" # *HELLO*|*GOOD*MORNING* => [*HELLO*, *GOOD*MORNING*]
    		for pattern in "${ARR[@]}"; do # *HELLO*
    			regex="^${pattern//'*'/.*}$" # .*HELLO.*
                if [[ $sanitized =~ $regex ]]; then # HELLO THERE =~ .*HELLO.*
                    action=${line#*==} # *HELLO*|*GOOD*MORNING*==say Hi => say Hi
    				action=`echo $action | sed 's/(\([0-9]\))/${BASH_REMATCH[\1]}/g'`
    				$verbose && my_debug "$> $action"
                    eval "$action" || say "$phrase_failed"
                    check_indented=true
                    commands=""
                    break
    			fi
    		done
        fi
	done <<< "${commands//\\/\\\\}" # https://github.com/alexylem/jarvis/issues/147
    if ! $check_indented; then
        say "$phrase_misunderstood: $order"
    elif [ -z "$commands" ]; then
        commands=`cat jarvis-commands plugins/*/${language:0:2}/commands 2>/dev/null`
    fi
}

handle_orders() {
    if [ -z "$separator" ]; then
        handle_order "$1"
    else
        orders=$(echo "$1" | awk "BEGIN {FS=\" `echo $separator` \"} {for(i=1;i<=NF;i++)print \$i}")
        while read order; do
            handle_order "$order"
        done <<< "$orders"
    fi
}

# if -x argument provided, just handle order & exit (used in jarvis-events)
if [[ "$just_execute" != false ]]; then
	handle_order "$just_execute"
	exit
fi

# check for updates
[ $check_updates = true ] && [ $just_listen = false ] && checkupdates

# Check if Jarvis is already running in background
if [ -e $lockfile ] && kill -0 `cat $lockfile` 2>/dev/null; then
    options=('Show Jarvis output' 'Stop Jarvis')
    case "`dialog_menu 'Jarvis is already running\nWhat would you like to do? (Cancel to let it run)' options[@]`" in
        Show*) cat jarvis.log;;
        Stop*)
            pid=`cat $lockfile` # process id de jarvis
            gid=`ps -p $pid -o pgid=` # group id de jarvis
            kill -TERM -`echo $gid`;; # tuer le group complet
    esac
    exit
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
    [[ "$OSTYPE" = darwin* ]] && os="$(sw_vers -productVersion)" || os="$(head -n1 /etc/*release | cut -f2 -d=)"
    system="$(uname -mrs)"
    echo -e "$_gray\n------------ Config ------------"
    for parameter in system os language play_hw rec_hw speaker microphone trigger_stt command_stt tts_engine conversation_mode; do
        printf "%-20s %s \n" "$parameter" "${!parameter}"
    done
    echo -e "--------------------------------\n$_reset"
fi

source hooks/program_startup
[ $just_listen = false ] && [ ! -z "$phrase_welcome" ] && say "$phrase_welcome"
bypass=$just_listen

trap "program_exit" INT TERM
echo $$ > $lockfile

# Display available commands to the user
my_debug "$commands" | cut -d '=' -f 1 | column

while true; do
	if [ $keyboard = true ]; then
        bypass=true
		read -p "$username: " order
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

            $verbose && my_debug "(listening...)"

            if $bypass; then
                eval ${command_stt}_STT
            else
                eval ${trigger_stt}_STT
            fi
			#$verbose && PLAY beep-low.wav

			order=`cat $forder`
            > $forder # empty $forder
			if [ -z "$order" ]; then
                printf '?'
                PLAY sounds/error.wav
                if [ $((++nb_failed)) -eq 3 ]; then
                    nb_failed=0
                    echo # new line
                    $verbose && my_debug "DEBUG: 3 attempts failed, end of conversation"
                    PLAY sounds/timeout.wav
                    bypass=false
                    source hooks/exiting_cmd
                    continue 2
                fi
                continue
            fi
			if $bypass; then
                printf "$order"
                break
            elif [[ "$order" == *$trigger_sanitized* ]]; then
                bypass=true
                echo $trigger # new line
                source hooks/entering_cmd
                say "$phrase_triggered"
                continue 2
            fi
			
			#$verbose && PLAY beep-error.wav
		done
		echo # new line
	fi
    was_in_conversation=$bypass
	[ -n "$order" ] && handle_orders "$order"
    if $was_in_conversation && [ $conversation_mode = false ]; then
        bypass=false
        source hooks/exiting_cmd
    fi
    $just_listen && [ $bypass = false ] && program_exit
done
