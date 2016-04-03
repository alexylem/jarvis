#!/bin/bash
clear
cat << EOF
+----------------------------------------------+
| >_ JARVIS - http://alexylem.github.io/jarvis |
| by Alexandre Mély - alexandre.mely@gmail.com |
+----------------------------------------------+
EOF
flags='bcefhikl:pqrs:tuvx'
show_help () { cat << EOF

    Usage: ${0##*/} [-$flags]

    Jarvis.sh is a dead simple configurable multi-lang jarvis-like bot
    Meant for home automation running on slow computer (ex: Raspberry Pi)
    Very few dependencies. Uses by default online speech recognition & synthesis

    -b  run in background (will continue after terminal is closed)
    -c  edit commands (what jarvis can recognize & execute)
    -e  edit events (jarvis pro-active voice notifications)
    -f  edit config
    -h  display this help
    -i  install (dependencies, pocketsphinx, setup)
    -k  read from keyboard instead of microphone
    -l  just listen to filename, ex: $0 -l "speech.wav"
    -p  report a problem
    -q  do not speak answer (just console)
    -r  uninstall (remove config files)
    -s  just say something, ex: ${0##*/} -s "hello world"
    -t  troubleshoot issues with jarvis
    -u  update (git pull)
    -v  verbose & VU meter - recommended for first launch / troubleshooting
    -x  build (do not use)

EOF
}

if [ "$(uname)" == "Darwin" ]; then
	platform="osx"
	dependencies=(awk git iconv nano perl sed sox wget)
	forder="/tmp/jarvis-order"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
	platform="linux"
	dependencies=(alsamixer aplay arecord awk git iconv mpg123 nano perl sed sox wget)
	forder="/dev/shm/jarvis-order"
else
	echo "Unsupported platform"; exit 1
fi

ask () { # usage ask "question" "varname" "default"
    if [ -z $3 ]; then
        read -p "$1 " $2
    elif [ ${BASH_VERSINFO[0]} -ge 4 ]; then
        read -e -p "$1 " -i "$3" $2
    else
        echo $1
        read -p "(default: $3) "
        eval $2="${REPLY:-$3}"
    fi
}

updateconfig () { # usage updateconfig default-file ($1) user-file ($2)
	if [ -f $2 ]; then
		if ! cmp --silent $1.old $1; then
			echo "$1 has changed, what do you want to do?"
			select opt in "Replace (you may loose your changes)" "Merge (you will choose what to keep)" "Ignore (not recommended)"; do
				case "$REPLY" in
					1 )	cp $1 $2
						break;;
					2 )	cat << EOF
Differences will now be displayed betweeen the two files for you to decide
Hint: increase your console width for easier comparison
Enter (l)eft to choose the left version (default file)
Enter (r)ight to choose the right version (your file)
If you are not sure, choose (l)eft
EOF
								read -p "Press [Enter] to start"
                                tabs 2 # sdiff --tabsize=2 not working
								sdiff -s -w `tput cols` -o $2.merged $1 $2
								mv $2.merged $2
								break;;
					3 ) break;;
				esac
			done
		fi
	else
		cp $1 $2
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

autoupdate () { # usage autoupdate 1 to show changelog
	printf "Updating..."
	cp jarvis-config-default.sh jarvis-config-default.sh.old
	cp jarvis-commands-default jarvis-commands-default.old
	cp jarvis-events-default jarvis-events-default.old
	git reset --hard HEAD >/dev/null # override any local change
	git pull -q &
	spinner $!
	echo " " # remove spinner
	updateconfig jarvis-config-default.sh jarvis-config.sh
	updateconfig jarvis-commands-default jarvis-commands
	updateconfig jarvis-events-default jarvis-events
	rm *.old
    clear
	echo "Update completed"
    [ $1 ] || return
    echo "Recent changes:"
    head CHANGELOG.md
    echo "[...] To see the full change log: more CHANGELOG.md"
}

DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
audiofile="jarvis-record.wav"
cd "$DIR" # needed now for git used in automatic update
rm -f $audiofile # sometimes, when error, previous recording is played
testaudiofile="applause.wav"
shopt -s nocasematch # string comparison case insensitive
[[ -f jarvis-config.sh ]] && source jarvis-config.sh

# default flags, use options to change see jarvis.sh -h
verbose=false
keyboard=false
quiet=false
play_hw=false
play_export=''
rec_hw=false
rec_export=''
just_say=false
just_listen=false
while getopts ":$flags" o; do
    case "${o}" in
		a)	all_matches=true;;
		b)  ./jarvis.sh > jarvis.log 2>&1 &
            disown
            echo "Jarvis has been launched in backbround"
            echo "To view Jarvis output: cat jarvis.log"
            echo "To check if jarvis is running: pgrep -l jarvis.sh"
            echo "To stop Jarvis: pkill jarvis.sh"
            echo "You can now close this terminal"
            exit;;
		c)	nano jarvis-commands; exit;;
		e)	echo "WARNING: JARVIS currently uses Crontab to schedule monitoring & notifications"
			echo "This will erase crontab entries you may already have, check with:"
			echo "	crontab -l"
			echo "If you already have crontab rules defined, add them to JARVIS events:"
			echo "	crontab -l >> jarvis-events"
			read -p "Press [Enter] to start editing Event Rules"
			nano jarvis-events
			crontab jarvis-events -i; exit;;
		f)	nano jarvis-config.sh; exit;;
		h)	show_help; exit;;
		i)	echo "JARVIS: Hello, my name is JARVIS, nice to meet you"
            echo "JARVIS: in which language shall we interact?"
            select opt in "English" "Français"; do
                case "$REPLY" in
                    1 )	language='en_EN'; break;;
                    2 )	language='fr_FR'; echo "JARVIS: I can only speak English during the installation"; break;;
                esac
            done
            ask "JARVIS: how do you want me to call you?" username $username
            read -p "JARVIS: Ok $username, press [Enter] to start the installation"
            clear
            echo 'Which Speech-To-Text engine to use for Trigger recognition ("JARVIS")?'
            select opt in "PocketSphinx (offline - recommended)" "Google (online)" "Wit.ai (online)"; do
                case "$REPLY" in
                    1 )	trigger_stt='pocketsphinx'; dependencies+=(wget perl); break;;
                    2 )	trigger_stt='google'; dependencies+=(curl perl); break;;
                    3 ) trigger_stt='wit'; break;;
                esac
            done
            clear
            echo 'Which Speech-To-Text engine to use for Command recognition?'
            select opt in "Google (online - recommended)" "Wit.ai (online)" "PocketSphinx (offline - not possible in French)"; do
                case "$REPLY" in
                    1 )	command_stt='google'; dependencies+=(wget perl); break;;
                    2 )	command_stt='wit'; dependencies+=(curl perl); break;;
                    3 ) command_stt='pocketsphinx'; break;;
                esac
            done
            clear
            echo 'Which Text-To-Speech engine would you like to use?'
            select opt in "Google (online - recommended)" "eSpeak (offline - Coming Soon)" "Say (offline - Mac OSX only)"; do
                case "$REPLY" in
                    1 )	tts_engine='google'; dependencies+=(wget mpg123); break;;
                    2 )	tts_engine='espeak'; dependencies+=(espeak); break;;
                    3 ) tts_engine='osx_say'; dependencies+=(say); break;;
                esac
            done
            clear
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
            if [ $trigger_stt = 'google' ] || [ $command_stt = 'google' ]; then
                clear
                echo "Obtain a Google Speech API Key here: http://stackoverflow.com/a/26833337"
                ask "Enter your Google Speech API Key:" google_speech_api_key $google_speech_api_key
            fi
            if [ $trigger_stt = 'wit' ] || [ $command_stt = 'wit' ]; then
                clear
                echo "Obtain a Wit Server Access Token here: https://wit.ai/apps/new"
                ask "Enter your Wit Server Access Token:" wit_server_access_token $wit_server_access_token
            fi
            if [ $trigger_stt = 'pocketsphinx' ] || [ $command_stt = 'pocketsphinx' ]; then
                hash pocketsphinx_continuous 2>/dev/null || {
                    clear
                    echo "PocketSphinx doesn't seem to be installed"
                    read -p "Press [Enter] to install it"
                    cd stt_engines/pocketsphinx
                    source install.sh || exit 1
                    cd ../../
                    read -p "Press [Enter] to continue"
                }
            fi
			while true; do
				clear
				read -p "Checking audio output, make sure your speakers are on and press [Enter]"
				[ $play_hw != false ] && play_export="AUDIODEV=$play_hw AUDIODRIVER=alsa"
				eval "$play_export play $testaudiofile"
				read -p "Did you hear something? (y)es (n)o or error (r)etry: " -n 1 -r
				if [[ $REPLY =~ ^[Yy]$ ]]; then break; fi
				if [[ $REPLY =~ ^[Rr]$ ]]; then continue; fi
				clear
				aplay -l
				read -p "Indicate the card # to use [0-9]: " card
				read -p "Indicate the device # to use [0-9]: " device
				play_hw="hw:$card,$device"
			done
			while true; do
				clear
				read -p "Checking audio input, make sure your microphone is on, press [Enter] and say something"
				[ $rec_hw != false ] && rec_export="AUDIODEV=$rec_hw AUDIODRIVER=alsa"
				eval "$rec_export rec $audiofile trim 0 3; $play_export play $audiofile"
				read -p "Did you hear yourself? (y)es (n)o or error (r)etry: " -n 1 -r
				echo # new line
				if [[ $REPLY =~ ^[Yy]$ ]]; then break; fi
				if [[ $REPLY =~ ^[Rr]$ ]]; then continue; fi
				clear
				arecord -l
				read -p "Indicate the card # to use [0-9]: " card
				read -p "Indicate the device # to use [0-9]: " device
				rec_hw="hw:$card,$device"
			done
			clear
			echo "We want to make sure the mic level is high enough"
			echo "Hit [Enter] and use [Arrows] to select Mic and raise volume to maximum"
			read
			alsamixer -c $card -V capture
			clear
            autoupdate
			sed -i.old "s/username=.*/username=$username/" jarvis-config.sh
            sed -i.old "s/language=.*/language=$language/" jarvis-config.sh
            sed -i.old "s/play_hw=false/play_hw=$play_hw/" jarvis-config.sh
			sed -i.old "s/rec_hw=false/rec_hw=$rec_hw/" jarvis-config.sh
            sed -i.old "s/trigger_stt=.*/trigger_stt=$trigger_stt/" jarvis-config.sh
            sed -i.old "s/command_stt=.*/command_stt=$command_stt/" jarvis-config.sh
            sed -i.old "s/tts_engine=.*/tts_engine=$tts_engine/" jarvis-config.sh
			clear
			cat << EOF
Installation complete.
What to do now?

Personalize JARVIS:
	./jarvis.sh -f
		to edit the config file
	./jarvis.sh -c
		to edit what JARVIS can understand and execute
	./jarvis.sh -e
		to edit what JARVIS monitors and notifies you about

Start JARVIS
	./jarvis.sh -v
		It is recommended to add -v (verbose) for the first execution
EOF
			exit;;
        k)	keyboard=true;;
        l)  just_listen=${OPTARG}
            echo "recording to: $just_listen";;
		p)	echo "Create an issue on GitHub"
			echo "https://github.com/alexylem/jarvis/issues/new"
			exit;;
		q)	quiet=true;;
		r)	rm -i $audiofile jarvis-config.sh jarvis-commands; exit;;
		s)	just_say=${OPTARG}
			echo "to say: $just_say";;
        t)  echo "Visit http://alexylem.github.io/jarvis/#faq"
            exit;;
		u)	autoupdate 1
			exit;;
		v)	verbose=true;;
        x)	cp jarvis-config.sh jarvis-config-default.sh
            sed -i.old -E 's/username=.*/username="`whoami`"/' jarvis-config-default.sh
            sed -i.old -E 's/language=.*/language=/' jarvis-config-default.sh
            sed -i.old -E 's/check_updates=.*/check_updates=true/' jarvis-config-default.sh
			sed -i.old -E 's/trigger_stt=.*/trigger_stt=/' jarvis-config-default.sh
            sed -i.old -E 's/command_stt=.*/command_stt=/' jarvis-config-default.sh
            sed -i.old -E 's/tts_engine=.*/tts_engine=/' jarvis-config-default.sh
            sed -i.old -E 's/(google_speech_api_key=").*(")/\1\2/' jarvis-config-default.sh
            sed -i.old -E 's/(wit_server_access_token=").*(")/\1\2/' jarvis-config-default.sh
            cp jarvis-commands jarvis-commands-default
			sed -i.old '/#PRIVATE/d' jarvis-commands-default
			rm *.old
			open -a "GitHub Desktop" /Users/alex/Documents/jarvis
			exit;;
        *)	echo "Usage: $0 [-$flags]" 1>&2; exit 1;;
    esac
done

# Load config file
if [ ! -f jarvis-config.sh ]; then
	echo "Missing config file. Install with command $>./jarvis -i" 1>&2
	exit 1
fi
source jarvis-functions.sh

# say wrapper to be used in jarvis-commands
say () { echo $trigger: $1; $quiet || TTS "$1"; }

# if -s argument provided, just say it & exit (used in jarvis-events)
if [[ "$just_say" != false ]]; then
	say "$just_say"
	exit
fi

# if -l argument provided, just listen it & exit
if [[ "$just_listen" != false ]]; then
    LISTEN "$just_listen"
	exit
fi

# check for updates
if "$check_updates"; then
	printf "Checking for updates..."
	git fetch origin -q &
	spinner $!
	case `git rev-list HEAD...origin/master --count || echo e` in
		"e") echo -e "[\033[31mError\033[0m]";;
		"0") echo -e "[\033[32mUp-to-date\033[0m]";;
		*)	echo -e "[\033[33mNew version available\033[0m]"
			read -p "A new version of JARVIS is available, would you like to update? [Y/n] " -n 1 -r
			echo    # (optional) move to a new line
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				autoupdate 1 # has spinner inside
				echo "Please restart JARVIS"
				exit
			fi
			;;
	esac
fi

settimeout () { # usage settimeout 10 command args
	local timeout=$1
	shift
	( $@ ) & pid=$!
	( sleep $timeout && kill -HUP $pid ) 2>/dev/null & watcher=$!
	wait $pid 2>/dev/null && pkill -HUP -P $watcher
}

handlecommand() {
	order=`echo $1 | iconv -f utf8 -t ascii//TRANSLIT | sed 's/[^a-zA-Z 0-9]//g'` # remove accents + osx hack http://stackoverflow.com/a/30832719	
	while read line; do
		patterns=${line%==*} # *HELLO*|*GOOD*MORNING*==say Hi => *HELLO*|*GOOD*MORNING*
		IFS='|' read -ra ARR <<< "$patterns" # *HELLO*|*GOOD*MORNING* => [*HELLO*, *GOOD*MORNING*]
		for pattern in "${ARR[@]}"; do # *HELLO*
			if [[ $order == $pattern ]]; then # HELLO THERE == *HELLO*
				action=${line#*==} # *HELLO*|*GOOD*MORNING*==say Hi => say Hi
				action="${action/.../$order}"
				$verbose && echo "$> $action"
                eval "$action" || say "$command_failed"
				$all_matches || return
			fi
		done
	done < jarvis-commands
	say "$unknown_command: $order"
}

say "$hello $username"
bypass=false
trap "exit" INT # exit jarvis with Ctrl+C
while true; do
	if [ $keyboard = true ]; then
		echo; echo $trigger: $welcome
		read -p "$username: " order
	else
		if [ $always_listening = false ]; then
			bypass=true
			read -p "Press [Enter] to start voice command"
		fi
		! $bypass && echo "$trigger: Waiting to hear '$trigger'"
		printf "$username: "
		$quiet || PLAY beep-high.wav
		while true; do
			#$quiet || PLAY beep-high.wav
			while true; do
				$bypass && timeout='settimeout 10' || timeout=''
				eval "$timeout LISTEN $audiofile"
				duration=`sox $audiofile -n stat 2>&1 | sed -n 's#^Length[^0-9]*\([0-9]*\).\([0-9]\)*$#\1\2#p'`
				$verbose && echo "DEBUG: speech duration was $duration"
				if $bypass; then
					if [ -z "$duration" ]; then
						$verbose && echo "DEBUG: timeout, end of hot conversation" || printf '.'
						PLAY beep-low.wav
						sleep 1 # BUG here despite timeout mic still busy can't rec again...
						bypass=false
						order='' # clean previous order
						break 2
					elif [ "$duration" -gt 40 ]; then
						$verbose && echo "DEBUG: too long for a command (max 4 secs), ignoring..." || printf '#'
						continue
					else
						break
					fi
				else
					if [ "$duration" -lt 2 ]; then
						$verbose && echo "DEBUG: too short for a trigger (min 0.2 max 1.5 sec), ignoring..." || printf '-'
						continue
					elif [ "$duration" -gt 20 ]; then
						$verbose && echo "DEBUG: too long for a trigger (min 0.5 max 1.5 sec), ignoring..." || printf '#'
						continue
					else
						break
					fi
				fi
			done
			$verbose && PLAY beep-low.wav
			$verbose && PLAY "$audiofile"
			STT "$audiofile" &
			spinner $!
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
	[ -n "$order" ] && handlecommand "$order"
done
