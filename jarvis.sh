#!/bin/bash
# +----------------------------------------+
# | JARVIS by Alexandre Mély - MIT license |
# | http://github.com/alexylem/jarvis/wiki |
# +----------------------------------------+
flags='bc:ihlns:'
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
    -s  just say something and exit, ex: ${0##*/} -s "hello world"

EOF
}

headline="NEW! Jarvis Store is now open!"

# Move to Jarvis directory
DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" # needed now for git used in automatic update

shopt -s nocasematch # string comparison case insensitive
source utils/utils.sh # needed for wizard / platform error

# Check platform compatibility
if [ "$(uname)" == "Darwin" ]; then
	platform="osx"
	dependencies=(awk curl git iconv nano osascript perl sed sox wget)
	forder="/tmp/jarvis-order"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
	platform="linux"
	dependencies=(alsamixer aplay arecord awk curl git iconv mpg123 nano perl sed sox wget whiptail)
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
mkdir -p store/installed
audiofile="jarvis-record.wav"
rm -f $audiofile # sometimes, when error, previous recording is played

# Only for retrocompatibility
update_commands () {
    # remove heading "Yes?" system trigger response, now a phrase
    grep -iv "^\*==" jarvis-commands > cmd.tmp; mv cmd.tmp jarvis-commands
    # remove traling "I don't understand" system command, now a phrase
    grep -iv "^\*$trigger\*==" jarvis-commands > cmd.tmp; mv cmd.tmp jarvis-commands
}

autoupdate () { # usage autoupdate 1 to show changelog
	printf "Updating..."
	git reset --hard HEAD >/dev/null # override any local change
	git pull -q &
	spinner $!
	echo " " # remove spinner
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
	spinner $!
	case `git rev-list HEAD...origin/master --count || echo e` in
		"e") echo -e "[\033[31mError\033[0m]";;
		"0") echo -e "[\033[32mUp-to-date\033[0m]";;
		*)	echo -e "[\033[33mNew version available\033[0m]"
            changes=$(git fetch -q 2>&1 && git log HEAD..origin/master --oneline --format="- %s (%ar)" | head -5)
            if dialog_yesno "A new version of JARVIS is available, recent changes:\n$changes\n\nWould you like to update?" false >/dev/null; then
				autoupdate 1 # has spinner inside
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
        bing_speech_api_key)   eval $1=`dialog_input "Bing Speech API Key\nHow to get one: https://github.com/alexylem/jarvis/wiki/bing" "${!1}"`;;
        check_updates)         eval $1=`dialog_yesno "Check Updates when Jarvis starts up (recommended)" "${!1}"`;;
        command_stt)           options=('bing' 'wit' 'pocketsphinx')
                               eval $1=`dialog_select "Which engine to use for the recognition of commands\nVisit https://github.com/alexylem/jarvis/wiki/stt\nRecommended: bing (google has been removed because deprecated)" options[@] "${!1}"`
                               source stt_engines/$command_stt/main.sh;;
        conversation_mode)     eval $1=`dialog_yesno "Wait for another command after first executed" "${!1}"`;;
        dictionary)            eval $1=`dialog_input "PocketSphinx dictionary file" "${!1}"`;;
        google_speech_api_key) eval $1=`dialog_input "Google Speech API Key\nHow to get one: http://stackoverflow.com/a/26833337" "${!1}"`;;
        program_startup)       editor hooks/$1;;
        program_exit)          editor hooks/$1;;
        entering_cmd)          editor hooks/$1;;
        exiting_cmd)           editor hooks/$1;;
        language)              options=("en_EN" "fr_FR")
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
        separator) eval $1=`dialog_input "Separator for multiple commands at once\nex: 'then' or empty to disable" "${!1}"`;;
        snowboy_sensitivity) eval $1=`dialog_input "Snowboy sensitivity from 0 (strict) to 1 (permissive)\nRecommended value: 0.5" "${!1}"`;;
        tmp_folder) eval $1=`dialog_input "Cache folder" "${!1}"`;;
        trigger)
            eval "$1='`dialog_input \"Magic word to be said\" \"${!1}\"`'"
            update_commands;;
        trigger_mode) options=("magic_word" "enter_key" "physical_button")
                 eval $1=`dialog_select "How to trigger Jarvis (before to say a command)" options[@] "${!1}"`;;
        trigger_stt) options=('snowboy' 'pocketsphinx' 'bing')
                     eval $1=`dialog_select "Which engine to use for the recognition of the trigger ($trigger)\nVisit https://github.com/alexylem/jarvis/wiki/stt\nRecommended: snowboy" options[@] "${!1}"`
                     if [ "$trigger_stt" = "snowboy" ]; then
                        # use ' instead of " in dialog_msg
                        dialog_msg <<EOM
You can record your own hotword with the following steps:
https://github.com/alexylem/jarvis/wiki/snowboy
Or you can immediately use the default universal hotword 'snowboy'
EOM
                        trigger="snowboy"
                        configure "trigger"
                    fi
                     source stt_engines/$trigger_stt/main.sh;;
        tts_engine) options=('svox_pico' 'google' 'espeak' 'osx_say')
                    recommended=`[ "$platform" = "osx" ] && echo 'osx_say' || echo 'svox_pico'`
                    eval $1=`dialog_select "Which engine to use for the speech synthesis\nVisit https://github.com/alexylem/jarvis/wiki/tts\nRecommended for your platform: $recommended" options[@] "${!1}"`
                    source tts_engines/$tts_engine/main.sh;;
        username) eval $1=`dialog_input "How would you like to be called?" "${!1}"`;;
        wit_server_access_token) eval $1=`dialog_input "Wit Server Access Token\nHow to get one: https://wit.ai/apps/new" "${!1}"`;;
        *) my_error "ERROR: Unknown configure $1";;
    esac
}

wizard () {
    checkupdates
    echo "Checking dependencies:"
    # remove dupplicates
    dependencies=(`echo "${dependencies[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '`)
    missing=()
    for i in "${dependencies[@]}"; do
        printf "$i: "
        if hash $i 2>/dev/null; then
            echo -e "[\033[32mInstalled\033[0m]"
        else
            echo -e "[\033[31mNot found\033[0m]"
            missing+=($i)
        fi
    done
    [ ${#missing[@]} -gt 0 ] && {
        echo "You must install missing dependencies before going further"
        echo "ex: sudo apt-get install -y ${missing[@]}"
        exit 1
    }
    read -p "Press [Enter] to continue"

    dialog_msg "Hello, my name is JARVIS, nice to meet you"
    configure "language"

    [ "$language" != "en_EN" ] && dialog_msg "Note: the installation & menus are only in English for the moment."

    configure "username"
    configure "trigger_stt"
    configure "command_stt"
    configure "tts_engine"

    if [ $trigger_stt = 'google' ] || [ $command_stt = 'google' ]; then
        configure "google_speech_api_key"
    fi
    if [ $trigger_stt = 'wit' ] || [ $command_stt = 'wit' ]; then
        configure "wit_server_access_token"
    fi
    if [ $trigger_stt = 'bing' ] || [ $command_stt = 'bing' ]; then
        configure "bing_speech_api_key"
    fi

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
		s)	just_say=${OPTARG};;
        *)	echo "Usage: $0 [-$flags]" 1>&2; exit 1;;
    esac
done

configure "load" || wizard
[ -n "$conversation_mode_override" ] && conversation_mode=$conversation_mode_override
update_commands
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

# say wrapper to be used in jarvis-commands
# USAGES:
#   say "hello world"
#   echo hello world | say
say () {
    set -- "${1:-$(</dev/stdin)}" "${@:2}"
    echo $trigger: $1; $quiet || TTS "$1";
}

# if -s argument provided, just say it & exit (used in jarvis-events)
if [[ "$just_say" != false ]]; then
	say "$just_say"
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
while [ "$no_menu" = false ]; do
    options=('Start Jarvis'
             'Settings'
             'Commands (what JARVIS can understand and execute)'
             'Events (what JARVIS monitors and notifies you about)'
             'Store (commands from community)'
             'Search for updates'
             'Help / Report a problem'
             'About')
    case "`dialog_menu \"Welcome to Jarvis\n$headline\" options[@]`" in
        Start*)
            while true; do
                options=('Start normally' 'Troubleshooting mode' 'Keyboard mode' 'Mute mode' 'Start as a service')
                case "`dialog_menu 'Start Jarvis' options[@]`" in
                    "Start normally")
                        break 2;;
                    "Troubleshooting mode")
                        verbose=true
                        break 2;;
                    "Keyboard mode")
                        keyboard=true
                        break 2;;
                    "Mute mode")
                        quiet=true
                        break 2;;
                    "Start as a service")
                        start_in_background
                        exit;;
                    *) break;;
                esac
            done;;
        Settings)
            while true; do
                options=('General' 'Phrases' 'Hooks' 'Audio' 'Voice recognition' 'Speech synthesis' 'Step-by-step wizard')
                case "`dialog_menu 'Configuration' options[@]`" in
                    "General")
                        while true; do
                            options=("Username ($username)" "Trigger ($trigger_mode)" "Magic word ($trigger)" "Multi-command separator ($separator)" "Conversation mode ($conversation_mode)" "Language ($language)" "Check Updates on Startup ($check_updates)")
                            case "`dialog_menu 'Configuration > General' options[@]`" in
                                Username*) configure "username";;
                                Trigger*) configure "trigger_mode";;
                                Magic*word*) configure "trigger";;
                                Multi-command*separator*) configure "separator";;
                                Conversation*) configure "conversation_mode";;
                                Language*) configure "language";;
                                Check*Updates*) configure "check_updates";;
                                *) break;;
                            esac
                        done;;
                    "Phrases")
                        while true; do
                            options=("Startup greetings ($phrase_welcome)" "Trigger reply ($phrase_triggered)" "Unknown order ($phrase_misunderstood)" "Command failed ($phrase_failed)")
                            case "`dialog_menu 'Configuration > Phrases' options[@]`" in
                                Startup*greetings*) configure "phrase_welcome";;
                                Trigger*reply*)     configure "phrase_triggered";;
                                Unknown*order*)     configure "phrase_misunderstood";;
                                Command*failed*)    configure "phrase_failed";;
                                *) break;;
                            esac
                        done;;
                    "Hooks")
                    while true; do
                        options=("Program startup" "Program exit" "Entering command mode" "Exiting command mode")
                        case "`dialog_menu 'Configuration > Hooks' options[@]`" in
                            Program*startup*) configure "program_startup";;
                            Program*exit*) configure "program_exit";;
                            Entering*) configure "entering_cmd";;
                            Exiting*) configure "exiting_cmd";;
                            *) break;;
                        esac
                    done;;
                    "Audio")
                        while true; do
                            options=("Speaker ($play_hw)" "Mic ($rec_hw)" "Volume" "Sensitivity" "Min noise duration to start ($min_noise_duration_to_start)" "Min noise perc to start ($min_noise_perc_to_start)" "Min silence duration to stop ($min_silence_duration_to_stop)" "Min silence level to stop ($min_silence_level_to_stop)" "Max noise duration to kill ($max_noise_duration_to_kill)")
                            case "`dialog_menu 'Configuration > Audio' options[@]`" in
                                Speaker*) configure "play_hw";;
                                Mic*) configure "rec_hw";;
                                Volume) if [ "$platform" == "osx" ]; then
                                            osascript <<EOM
                                                tell application "System Preferences"
                                                    activate
                                                    set current pane to pane "com.apple.preference.sound"
                                                    reveal (first anchor of current pane whose name is "output")
                                                end tell
EOM
                                        else
                                            alsamixer -c ${play_hw:3:1} -V playback || read -p "ERROR: check above"
                                        fi;;
                                Sensitivity)
                                if [ "$platform" == "osx" ]; then
                                            osascript <<EOM
                                                tell application "System Preferences"
                                                    activate
                                                    set current pane to pane "com.apple.preference.sound"
                                                    reveal (first anchor of current pane whose name is "input")
                                                end tell
EOM
                                        else
                                            alsamixer -c ${rec_hw:3:1} -V capture || read -p "ERROR: check above"
                                        fi;;
                                *duration*start*) configure "min_noise_duration_to_start";;
                                *perc*start*) configure "min_noise_perc_to_start";;
                                *duration*stop*) configure "min_silence_duration_to_stop";;
                                *level*stop*) configure "min_silence_level_to_stop";;
                                *duration*kill*) configure "max_noise_duration_to_kill";;
                                *) break;;
                            esac
                        done;;
                    "Voice recognition")
                        while true; do
                            options=("Recognition of magic word ($trigger_stt)"
                                     "Recognition of commands ($command_stt)"
                                     "Snowboy sensitivity ($snowboy_sensitivity)"
                                     "Bing key ($bing_speech_api_key)"
                                     #"Google key ($google_speech_api_key)"
                                     "Wit key ($wit_server_access_token)"
                                     "PocketSphinx dictionary ($dictionary)"
                                     "PocketSphinx language model ($language_model)"
                                     "PocketSphinx logs ($pocketsphinxlog)")
                            case "`dialog_menu 'Configuration > Voice recognition' options[@]`" in
                                Recognition*magic*word*) configure "trigger_stt";;
                                Recognition*command*)       configure "command_stt";;
                                Snowboy*)                   configure "snowboy_sensitivity";;
                                #Google*)                    configure "google_speech_api_key";;
                                Wit*)                       configure "wit_server_access_token";;
                                Bing*key*)                  configure "bing_speech_api_key";;
                                PocketSphinx*dictionary*)   configure "dictionary";;
                                PocketSphinx*model*)        configure "language_model";;
                                PocketSphinx*logs*)         configure "pocketsphinxlog";;
                                *) break;;
                            esac
                        done;;
                    "Speech synthesis")
                        while true; do
                            options=("Speech engine ($tts_engine)" "OSX voice ($osx_say_voice)" "Cache folder ($tmp_folder)")
                            case "`dialog_menu 'Configuration > Speech synthesis' options[@]`" in
                                Speech*engine*) configure "tts_engine";;
                                OSX*voice*)     configure "osx_say_voice";;
                                Cache*folder*)  configure "tmp_folder";;
                                *) break;;
                            esac
                        done;;
                    "Step-by-step wizard")
                        wizard;;
                    *) break;;
                esac
            done
            configure "save";;
        Commands*)
            editor jarvis-commands
            update_commands;;
        Events*)
            dialog_msg <<EOM
WARNING: JARVIS currently uses Crontab to schedule monitoring & notifications
This will erase crontab entries you may already have, check with:
	crontab -l
If you already have crontab rules defined, add them to JARVIS events:
	crontab -l >> jarvis-events
Press [Ok] to start editing Event Rules
EOM
            editor jarvis-events &&
            crontab jarvis-events -i;;
        Store*)
            while true; do
                shopt -s nullglob
                nb_installed=(store/installed/*/)
                nb_all=(store/all/*/)
                shopt -u nullglob
                options=("Installed (${#nb_installed[@]})"
                         "Search"
                         "Browse (${#nb_all[@]})"
                         "Publish")
                case "`dialog_menu 'Store' options[@]`" in
                    Installed*) if [ "${#nb_installed[@]}" -gt 0 ]; then
                                    cd store/installed/
                                    while true; do
                                        shopt -s nullglob
                                        options=(*)
                                        shopt -u nullglob
                                        option="`dialog_menu 'Installed' options[@]`"
                                        if [ -n "$option" ] && [ "$option" != "false" ]; then
                                            options=("Info"
                                                     "Configure"
                                                     "Uninstall")
                                            while true; do
                                                case "`dialog_menu \"$option\" options[@]`" in
                                                    Info)      clear
                                                               more "$option/info.md"
                                                               my_debug "Press [Enter] to continue"
                                                               read
                                                               ;;
                                                    Configure) editor "$option/config.sh";;
                                                    Uninstall)
                                                            if dialog_yesno "Are you sure?" true >/dev/null; then
                                                                "$option"/uninstall.sh
                                                                rm -rf "$option"
                                                                dialog_msg "Uninstallation Complete"
                                                                break 2
                                                            fi
                                                            ;;
                                                    *)       break;;
                                                esac
                                            done
                                        else
                                            break
                                        fi
                                    done
                                    cd ../../
                                fi
                                ;;
                    Search*)    ;;
                    Browse*)    cd store/all/
                                while true; do
                                    shopt -s nullglob # http://stackoverflow.com/questions/18884992/how-do-i-assign-ls-to-an-array-in-linux-bash
                                    options=(*)
                                    shopt -u nullglob
                                    option="`dialog_menu 'Store' options[@]`"
                                    if [ -n "$option" ] && [ "$option" != "false" ]; then
                                        clear
                                        more "$option/info.md"
                                        my_debug "Press [Enter] to continue"
                                        read
                                        options=("Info"
                                                 "Install")
                                        while true; do
                                            case "`dialog_menu \"$option\" options[@]`" in
                                                Info)    clear
                                                         more "$option/info.md"
                                                         my_debug "Press [Enter] to continue"
                                                         read
                                                         ;;
                                                Install) cp -R "$option" ../installed
                                                         cd ../installed
                                                         $option/install.sh
                                                         if [[ -s "$option/config.sh" ]]; then
                                                             dialog_msg "This plugin needs variables to be set"
                                                             editor "$option/config.sh"
                                                         fi
                                                         dialog_msg "Installation Complete"
                                                         break 2;;
                                                *)       break;;
                                            esac
                                        done
                                    else
                                        break
                                    fi
                                done
                                cd ../../
                                ;;
                    Publish*)   dialog_msg <<EOM
Why keeping your great Jarvis commands just for you?
Share them and have the whole community using them!
It's easy, and a great way to make one's contribution to the project.
Procedure to publish your commands on the Jarvis Store:
https://github.com/alexylem/jarvis/wiki/store
EOM
                                ;;
                    *) break;;
                esac
            done;;
        Help*)
            dialog_msg <<EOM
A question?
https://github.com/alexylem/jarvis/wiki/support

A problem or enhancement request?
Create a ticket on GitHub
https://github.com/alexylem/jarvis/issues/new

Just want to discuss?
https://disqus.com/home/discussion/coinche/jarvis/
EOM
            ;;
        "About") dialog_msg <<EOM
JARVIS
By Alexandre Mély

https://github.com/alexylem/jarvis/wiki
alexandre.mely@gmail.com
(I don't give support via email, please check Help)

JARVIS is freely distributable under the terms of the MIT license.
EOM
            ;;
        "Search for updates")
            checkupdates;;
        *) exit;;
    esac
done

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

for f in store/installed/*/config.sh; do source $f; done
commands=`cat jarvis-commands store/installed/*/commands 2>/dev/null`
handle_order() {
    order=`echo $1 | iconv -f utf-8 -t ascii//TRANSLIT | sed 's/[^a-zA-Z 0-9]//g'` # remove accents + osx hack http://stackoverflow.com/a/30832719
	local check_indented=false
    while read line; do
		if $check_indented; then
            #echo "checking if possible answers in: $line"
            if [ "${line:0:1}" = ">" ]; then
                newline=$'\n'
                commands="$commands$newline${line:1}"
            else
                if [ -z "$commands" ]; then
                    commands=`cat jarvis-commands store/installed/*/commands 2>/dev/null`
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
                if [[ $order =~ $regex ]]; then # HELLO THERE =~ .*HELLO.*
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
	done <<< "$commands"
    if ! $check_indented; then
        say "$phrase_misunderstood: $order"
    elif [ -z "$commands" ]; then
        commands=`cat jarvis-commands store/installed/*/commands 2>/dev/null`
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

source hooks/program_startup
[ $just_listen = false ] && [ ! -z "$phrase_welcome" ] && say "$phrase_welcome"
bypass=$just_listen

program_exit () {
    $verbose && my_debug "DEBUG: program exit handler"
    source hooks/program_exit $1
    # make sure the lockfile is removed when we exit and then claim it
    rm -f $lockfile
    exit $1
}
trap "program_exit" INT TERM
echo $$ > $lockfile

while true; do
	if [ $keyboard = true ]; then
        bypass=true
		read -p "$username: " order
	else
		if [ "$trigger_mode" = "enter_key" ]; then
			bypass=true
			read -p "Press [Enter] to start voice command"
		fi
		! $bypass && echo "$trigger: Waiting to hear '$trigger'"
		printf "$username: "

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
			printf "$order"
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
			$bypass && break
            if [[ "$order" == *$trigger* ]]; then
                bypass=true
                echo # new line
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
