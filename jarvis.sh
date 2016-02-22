#!/bin/bash
cat << EOF
+----------------------------------------------+
| >_ JARVIS - http://alexylem.github.io/jarvis |
| by Alexandre Mély - alexandre.mely@gmail.com |
+----------------------------------------------+
EOF
flags='bcehikqruv'
show_help () { cat << EOF
	
	Usage: ${0##*/} [-$flags]
	
	Jarvis.sh is a dead simple configurable multi-lang jarvis-like bot
 	Meant for home automation running on slow computer (ex: Raspberry Pi)
	It has few dependencies and uses online speech recognition & synthesis
	
	-b	build (do not use)
	-c	edit commands
	-e	edit config
	-h	display this help
	-i	install (check dependencies & init config files)
	-k	read from keyboard instead of microphone
	-q	do not speak answer (just console)
	-r	uninstall (remove config files)
	-u	update (git pull)
	-v	verbose & VU meter - recommended for first launch / troubleshooting

EOF
}

if [ "$(uname)" == "Darwin" ]; then
	platform="osx"
	dependencies=(awk git iconv nano perl sed sox wget)
	forder="/tmp/jarvis-order"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
	platform="linux"
	dependencies=(aplay arecord awk git iconv mpg123 nano perl sed sox wget)
	forder="/dev/shm/jarvis-order"
else
	echo "Unsupported platform"; exit 1
fi

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
Enter (l)eft to choose the left version (default file)
Enter (r)ight to choose the right version (your file)
If you are not sure, choose (l)eft
EOF
								sdiff -w 80 -o $2.merged $1 $2
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

DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
audiofile="$DIR/jarvis-record.wav"
rm -f $audiofile # sometimes, when error, previous recording is played
testaudiofile="$DIR/applause.wav"
shopt -s nocasematch # string comparison case insensitive

# default flags, use options to change see jarvis.sh -h
verbose=false
keyboard=false
quiet=false
play_hw=false
play_export=''
rec_hw=false
rec_export=''
while getopts ":$flags" o; do
    case "${o}" in
		a)	all_matches=true;;
		b)	cp $DIR/jarvis-config.sh $DIR/jarvis-config-default.sh
			sed -i.old -E 's/(google_speech_api_key=").*(")/\1YOUR_GOOGLE_SPEECH_API_KEY\2/' jarvis-config-default.sh
			cp $DIR/jarvis-functions.sh $DIR/jarvis-functions-default.sh
			cp $DIR/jarvis-commands $DIR/jarvis-commands-default
			sed -i.old '/#PRIVATE/d' jarvis-commands-default
			open -a "GitHub Desktop" /Users/alex/Documents/jarvis
			exit;;
		c)	nano $DIR/jarvis-commands; exit;;
		e)	nano $DIR/jarvis-config.sh; exit;;
		h)	show_help; exit;;
		i)	echo "Checking dependencies:"
			missing=false
			for i in "${dependencies[@]}"; do
		   		printf "$i: "
				if hash $i 2>/dev/null; then
					echo -e "[\033[32mInstalled\033[0m]"
				else
					echo -e "[\033[31mNot found\033[0m]"
					missing=true
				fi
		  	done
			$missing && read -p "WARNING: You may want to install missing dependencies based on your plateform"
			while true; do
				read -p "Checking audio output, make sure your speakers are on and press [Enter]"
				[ $play_hw ] && play_export="AUDIODEV=$play_hw AUDIODRIVER=alsa"
				eval "$play_export play $testaudiofile"
				read -p "Did you hear something? (y)es (n)o (r)etry: "
				if [[ $REPLY =~ ^[Yy]$ ]]; then break; fi
				if [[ $REPLY =~ ^[Rr]$ ]]; then continue; fi
				aplay -l
				read -p "Indicate the card # to use [0-9]: " card
				read -p "Indicate the device # to use [0-9]: " device
				play_hw="hw:$card,$device"
			done
			while true; do
				read -p "Checking audio input, make sure your microphone is on, press [Enter] and say something"
				[ $rec_hw ] && rec_export="AUDIODEV=$rec_hw AUDIODRIVER=alsa"
				eval "$rec_export rec $audiofile trim 0 3; $play_export play $audiofile"
				read -p "Did you hear yourself? (y)es (n)o (r)etry: "
				echo # new line
				if [[ $REPLY =~ ^[Yy]$ ]]; then break; fi
				if [[ $REPLY =~ ^[Rr]$ ]]; then continue; fi
				arecord -l
				read -p "Indicate the card # to use [0-9]: " card
				read -p "Indicate the device # to use [0-9]: " device
				rec_hw="hw:$card,$device"
			done
			updateconfig $DIR/jarvis-config-default.sh $DIR/jarvis-config.sh
			updateconfig $DIR/jarvis-functions-default.sh $DIR/jarvis-functions.sh
			updateconfig $DIR/jarvis-commands-default $DIR/jarvis-commands
			sed -i.bak "s/play_hw=false/play_hw=$play_hw/" $DIR/jarvis-config.sh
			sed -i.bak "s/rec_hw=false/rec_hw=$rec_hw/" $DIR/jarvis-config.sh
			cp -i pocketsphinx-dictionary-default.dic pocketsphinx-dictionary.dic
			cp -i pocketsphinx-languagemodel-default.lm pocketsphinx-languagemodel.lm
			read -p "Press [Enter] to edit the config file. Please follow instructions."
			nano $DIR/jarvis-config.sh
			echo "Installation complete."
			echo "It is recommended for the first time to run Jarvis in verbose mode:"
			echo "	./jarvis -v"
			exit;;
        k)	keyboard=true;;
		q)	quiet=true;;
		r)	rm -i $audiofile $DIR/jarvis-config.sh $DIR/jarvis-commands; exit;;
		u)	cd $DIR
			cp jarvis-config-default.sh jarvis-config-default.sh.old
			cp jarvis-functions-default.sh jarvis-functions-default.sh.old
			cp jarvis-commands-default jarvis-commands-default.old
			git reset --hard HEAD # override any local change
			git pull
			updateconfig jarvis-config-default.sh jarvis-config.sh
			updateconfig jarvis-functions-default.sh jarvis-functions.sh
			updateconfig jarvis-commands-default jarvis-commands
			# rm *.old
			cp -i pocketsphinx-dictionary-default.dic pocketsphinx-dictionary.dic
			cp -i pocketsphinx-languagemodel-default.lm pocketsphinx-languagemodel.lm
			exit;;
		v)	verbose=true;;
        *)	echo "Usage: $0 [-$flags]" 1>&2; exit 1;;
    esac
done

rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"
}

settimeout () { # usage settimeout 10 command args
	local timeout=$1
	shift
	( $@ ) & pid=$!
	( sleep $timeout && kill -HUP $pid ) 2>/dev/null & watcher=$!
	wait $pid 2>/dev/null && pkill -HUP -P $watcher
}

# Load config file
if [ ! -f $DIR/jarvis-config.sh ]; then
	echo "Missing config file. Install with command $>./jarvis -i" 1>&2
	exit 1
fi
source $DIR/jarvis-config.sh
source $DIR/jarvis-functions.sh

# say wrapper to be used in jarvis-commands
say () { echo $trigger: $1; $quiet || TTS "$1"; }

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
	done < $DIR/jarvis-commands
	say "$unknown_command: $order"
}

spinner(){ # call spinner $!
	while kill -0 $1 2>/dev/null; do
		for i in \| / - \\; do
			printf '%c\b' $i
			sleep .1
		done
	done
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
		$trigger_mode && ! $bypass && echo "$trigger: Waiting to hear '$trigger'"
		printf "$username: "
		$quiet || PLAY $DIR/beep-high.wav
		while true; do
			#$quiet || PLAY $DIR/beep-high.wav
			while true; do
				$bypass && timeout='settimeout 10' || timeout=''
				$timeout LISTEN $audiofile
				duration=`sox $audiofile -n stat 2>&1 | sed -n 's#^Length[^0-9]*\([0-9]*\).\([0-9]\)*$#\1\2#p'`
				$verbose && echo "DEBUG: speech duration was $duration"
				if $bypass; then
					if [ -z "$duration" ]; then
						$verbose && echo "DEBUG: timeout, end of hot conversation" || printf '.'
						PLAY $DIR/beep-low.wav
						sleep 5 # sometimes mic still busy
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
			$verbose && PLAY $DIR/beep-low.wav
			$verbose && PLAY "$audiofile"
			STT "$audiofile" &
			spinner $!
			order=`cat $forder`
			printf "$order"
			[ -z "$order" ] && printf '?' && continue
			if ! $trigger_mode || $bypass || [[ "$order" == *$trigger* ]]; then
				break
			fi
			$verbose && PLAY $DIR/beep-error.wav
		done
		echo # new line
	fi
	[ -n "$order" ] && handlecommand "$order"
done
