#!/bin/bash
# +----------------------------------------+
# | JARVIS by Alexandre Mély - MIT license |
# | http://github.com/alexylem/jarvis/wiki |
# +----------------------------------------+
flags='bihlns:'
show_help () { cat <<EOF

    Usage: ${0##*/} [-$flags]
    
    Jarvis.sh is a lightweight configurable multi-lang jarvis-like bot
    Meant for home automation running on slow computer (ex: Raspberry Pi)
    It installs automatically speech recognition & synthesis engines of your choice
    
    Main options are now accessible through the application menu
    
    -b  run in background (no menu, continues after terminal is closed)
    -i  install (dependencies, pocketsphinx, setup)
    -h  display this help
    -l  directly listen for one command (ex: launch from physical button)
    -n  directly start jarvis without menu
    -s  just say something and exit, ex: ${0##*/} -s "hello world"

EOF
}

DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
audiofile="jarvis-record.wav"
lockfile="/tmp/jarvis.lock"
cd "$DIR" # needed now for git used in automatic update
rm -f $audiofile # sometimes, when error, previous recording is played
shopt -s nocasematch # string comparison case insensitive

if [ "$(uname)" == "Darwin" ]; then
	platform="osx"
	dependencies=(awk git iconv nano osascript perl sed sox wget)
	forder="/tmp/jarvis-order"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
	platform="linux"
	dependencies=(alsamixer aplay arecord awk git iconv mpg123 nano perl sed sox wget whiptail)
	forder="/dev/shm/jarvis-order"
else
	echo "Unsupported platform"; exit 1
fi
source utils/dialog_$platform.sh

editor () {
    if [ $platform = 'osx' ]; then
        dialog_msg "Make sure to Quit (cmd+Q) the Editor when finished"
        open -tW "$1"
    else
        nano "$1"
    fi
}

spinner(){ # call spinner $!
	while kill -0 $1 2>/dev/null; do
		for i in \| / - \\; do
			printf '%c\b' $i
			sleep .1
		done
	done
}

update_commands () { # adds trigger and don't know commands
    line=$(head -n 1 jarvis-commands)
    pattern=${line%==*}
    [ "$pattern" != "*$trigger*" ] && echo "*$trigger*==bypass=true; say \"Oui?\"" | cat - jarvis-commands > /tmp/out && mv /tmp/out jarvis-commands
    line=$(tail -n 1 jarvis-commands)
    pattern=${line%==*}
    [ "$pattern" != "*" ] && echo "*==say \"Je ne comprends pas: \$order\"" >> jarvis-commands
}

autoupdate () { # usage autoupdate 1 to show changelog
	printf "Updating..."
	git reset --hard HEAD >/dev/null # override any local change
	git pull -q &
	spinner $!
	echo " " # remove spinner
    [ $1 ] || return
    clear
    echo "Update completed"
    echo "Recent changes:"
    head CHANGELOG.md
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
			if dialog_yesno "A new version of JARVIS is available, would you like to update?" false; then
				autoupdate 1 # has spinner inside
				dialog_msg "Please restart JARVIS"
				exit
			fi
			;;
	esac
}

# config
configure () {
    variables=('all_matches'
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
               'play_hw'
               'pocketsphinxlog'
               'rec_hw'
               'tmp_folder'
               'trigger'
               'trigger_stt'
               'trigger_mode'
               'tts_engine'
               'username'
               'wit_server_access_token')
    case "$1" in
        all_matches) eval $1=`dialog_yesno "Execute all matching commands (else only first match)" "${!1}"`;;
        check_updates) eval $1=`dialog_yesno "Check Updates when Jarvis starts up (recommended)" "${!1}"`;;
        command_stt) options=('google' 'wit' 'pocketsphinx')
                     eval $1=`dialog_select "Which engine to use for the recognition of commands\nRecommended: google" options[@] "${!1}"`
                     source stt_engines/$command_stt/main.sh;;
        conversation_mode) eval $1=`dialog_yesno "Wait for another command after first executed" "${!1}"`;;
        dictionary) eval $1=`dialog_input "PocketSphinx dictionary file" "${!1}"`;;
        google_speech_api_key) eval $1=`dialog_input "Google Speech API Key\nHow to get one: http://stackoverflow.com/a/26833337" "${!1}"`;;
        language) options=("en_EN" "fr_FR")
                  eval $1=`dialog_select "Language" options[@] "${!1}"`;;
        language_model) eval $1=`dialog_input "PocketSphinx language model file" "${!1}"`;;
        load) 
            source jarvis-config-default.sh
            [ -f jarvis-config.sh ] && source jarvis-config.sh # backward compatibility
            missing=0
            for varname in "${variables[@]}"; do
                [ -f "config/$varname" ] &&  eval $varname=`cat config/$varname` || missing=1
            done
            return $missing;;
        max_noise_duration_to_kill) eval $1=`dialog_input "Max noise duration to kill" "${!1}"`;;
        min_noise_duration_to_start) eval $1=`dialog_input "Min noise duration to start" "${!1}"`;;
        min_noise_perc_to_start) eval $1=`dialog_input "Min noise durpercentageation to start" "${!1}"`;;
        min_silence_duration_to_stop) eval $1=`dialog_input "Min silence duration to stop" "${!1}"`;;
        min_silence_level_to_stop) eval $1=`dialog_input "Min silence level to stop" "${!1}"`;;
        play_hw)
            while true; do
                dialog_msg "Checking audio output, make sure your speakers are on and press [Ok]"
                play "applause.wav"
                dialog_yesno "Did you hear something?" true && break
                clear
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
                rec $audiofile trim 0 3
                play $audiofile
                dialog_yesno "Did you hear yourself?" true && break
                clear
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
        tmp_folder) eval $1=`dialog_input "Cache folder" "${!1}"`;;
        trigger)
            eval $1=`dialog_input "Magic word to be said?" "${!1}"`
            trigger=`echo "$trigger" | tr '[:upper:]' '[:lower:]'` # to lowercase (for snowboy)
            update_commands;;
        trigger_mode) options=("magic_word" "enter_key" "physical_button")
                 eval $1=`dialog_select "How to trigger Jarvis (before to say a command)" options[@] "${!1}"`;;
        trigger_stt) options=('snowboy' 'pocketsphinx' 'google')
                     eval $1=`dialog_select "Which engine to use for the recognition of the trigger ($trigger)\nhttps://github.com/alexylem/jarvis/wiki/stt\nRecommended: snowboy" options[@] "${!1}"`
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
                    eval $1=`dialog_select "Which engine to use for the speech synthesis\nhttps://github.com/alexylem/jarvis/wiki/stt\nRecommended for your platform: $recommended" options[@] "${!1}"`
                    source tts_engines/$tts_engine/main.sh;;
        username) eval $1=`dialog_input "How would you like to be called?" "${!1}"`;;
        wit_server_access_token) eval $1=`dialog_input "Wit Server Access Token\nHow to get one: https://wit.ai/apps/new" "${!1}"`;;
        *) echo "ERROR: Unknown configure $1";;
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

# load default & user configuration
configure "load" || wizard
update_commands
source jarvis-functions.sh
source stt_engines/$trigger_stt/main.sh
source stt_engines/$command_stt/main.sh
source tts_engines/$tts_engine/main.sh
source utils/utils.sh
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
say () { echo $trigger: $1; $quiet || TTS "$1"; }

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
# make sure the lockfile is removed when we exit and then claim it
trap "rm -f $lockfile; exit" INT TERM EXIT
echo $$ > $lockfile

# main menu
while [ "$no_menu" = false ]; do
    options=('Start Jarvis' 'Settings' 'Commands (what JARVIS can understand and execute)' 'Events (what JARVIS monitors and notifies you about)' 'Search for updates' 'Help / Report a problem' 'About')
    case "`dialog_menu 'Welcome to Jarvis' options[@]`" in
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
                options=('General' 'Audio' 'Voice recognition' 'Speech synthesis' 'Step-by-step wizard')
                case "`dialog_menu 'Configuration' options[@]`" in
                    "General")
                        while true; do
                            options=("Username ($username)" "Trigger ($trigger_mode)" "Magic word ($trigger)" "Conversation mode ($conversation_mode)" "Language ($language)" "All Matches ($all_matches)" "Check Updates on Startup ($check_updates)")
                            case "`dialog_menu 'Configuration > General' options[@]`" in
                                Username*) configure "username";;
                                Trigger*) configure "trigger_mode";;
                                Magic*word*) configure "trigger";;
                                Conversation*) configure "conversation_mode";;
                                Language*) configure "language";;
                                All*Matches*) configure "all_matches";;
                                Check*Updates*) configure "check_updates";;
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
                            options=("Recognition of magic word ($trigger_stt)" "Recognition of commands ($command_stt)" "Google key ($google_speech_api_key)" "Wit key ($wit_server_access_token)" "PocketSphinx dictionary ($dictionary)" "PocketSphinx language model ($language_model)" "PocketSphinx logs ($pocketsphinxlog)")
                            case "`dialog_menu 'Configuration > Voice recognition' options[@]`" in
                                Recognition*magic*word*) configure "trigger_stt";;
                                Recognition*command*) configure "command_stt";;
                                Google*) configure "google_speech_api_key";;
                                Wit*) configure "wit_server_access_token";;
                                PocketSphinx*dictionary*) configure "dictionary";;
                                PocketSphinx*model*) configure "language_model";;
                                PocketSphinx*logs*) configure "pocketsphinxlog";;
                                *) break;;
                            esac
                        done;;
                    "Speech synthesis")
                        while true; do
                            options=("Speech engine ($tts_engine)" "Cache folder ($tmp_folder)")
                            case "`dialog_menu 'Configuration > Speech synthesis' options[@]`" in
                                Speech*engine*) configure "tts_engine";;
                                Cache*folder*) configure "tmp_folder";;
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

# troubleshooting info
if [ $verbose = true ]; then
    echo -e "\n------- Config (verbose) -------"
    for parameter in platform language play_hw rec_hw trigger_stt command_stt tts_engine google_speech_api_key; do
        printf "%-21s %s \n" "$parameter" "${!parameter}"
    done
    echo -e "--------------------------------\n"
fi

handlecommand() {
	order=`echo $1 | iconv -f utf8 -t ascii//TRANSLIT | sed 's/[^a-zA-Z 0-9]//g'` # remove accents + osx hack http://stackoverflow.com/a/30832719	
	while read line; do
		patterns=${line%==*} # *HELLO*|*GOOD*MORNING*==say Hi => *HELLO*|*GOOD*MORNING*
		IFS='|' read -ra ARR <<< "$patterns" # *HELLO*|*GOOD*MORNING* => [*HELLO*, *GOOD*MORNING*]
		for pattern in "${ARR[@]}"; do # *HELLO*
			regex="^${pattern//'*'/.*}$" # .*HELLO.*
            if [[ $order =~ $regex ]]; then # HELLO THERE =~ .*HELLO.*
				action=${line#*==} # *HELLO*|*GOOD*MORNING*==say Hi => say Hi
				action=`echo $action | sed 's/(\([0-9]\))/${BASH_REMATCH[\1]}/g'`
				$verbose && echo "$> $action"
                eval "$action" || say "$command_failed"
				$all_matches || return
			fi
		done
	done < jarvis-commands
	say "$unknown_command: $order" # TODO not used anymore as in commands?
}

# don't check updates if directly in command mode
if [ $just_listen = true ]; then
    bypass=true
else
    say "$hello $username"
    bypass=false
fi

while true; do
	if [ $keyboard = true ]; then
		echo; echo $trigger: $welcome
		read -p "$username: " order
	else
		if [ "$trigger_mode" = "enter_key" ]; then
			bypass=true
			read -p "Press [Enter] to start voice command"
		fi
		! $bypass && echo "$trigger: Waiting to hear '$trigger'"
		printf "$username: "
		
        $quiet || ( $bypass && PLAY beep-high.wav || PLAY beep-low.wav )
		
        while true; do
			#$quiet || PLAY beep-high.wav
			
            $verbose && echo "(listening...)"
            
            if $bypass; then
                eval ${command_stt}_STT
            else
                eval ${trigger_stt}_STT
            fi
			$verbose && PLAY beep-low.wav
            
			order=`cat $forder`
			printf "$order"
			[ -z "$order" ] && printf '?' && continue
			if $bypass || [[ "$order" == *$trigger* ]]; then
				break
			fi
			$verbose && PLAY beep-error.wav
		done
		echo # new line
	fi
    was_in_conversation=$bypass
	[ -n "$order" ] && handlecommand "$order"
    $was_in_conversation && [ $conversation_mode = false ] && bypass=false
    $just_listen && [ $bypass = false ] && exit
done
