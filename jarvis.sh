#!/bin/bash
flags='bcehikqruv'
show_help () { cat << EOF
	
	Usage: ${0##*/} [-$flags]
	
	Jarvis.sh is a dead simple configurable multi-lang jarvis-like bot
 	Meant for home automation running on slow computer (ex: Raspberry Pi)
	It has almost no dependency and uses Google speech recognition & synthesis
	
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

DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
audiofile="$DIR/jarvis-record.flac"
shopt -s nocasematch # string comparison case insensitive

# default flags, use options to change see jarvis.sh -h
verbose=false
keyboard=false
quiet=false
while getopts ":$flags" o; do
    case "${o}" in
		a)	all_matches=true;;
		b)	cp $DIR/jarvis-config.sh $DIR/jarvis-config-default.sh
			sed -i '' -E 's/(google_speech_api_key=").*(")/\1YOUR_GOOGLE_SPEECH_API_KEY\2/' jarvis-config-default.sh
			cp $DIR/jarvis-commands $DIR/jarvis-commands-default
			sed -i '' '/#PRIVATE/d' jarvis-commands-default
			exit;;
		c)	nano $DIR/jarvis-commands; exit;;
		e)	nano $DIR/jarvis-config.sh; exit;;
		h)	show_help; exit;;
		i)	echo "Checking dependencies:"
			missing=false
			for i in awk git iconv mpg321 nano perl sed sox wget; do
		   		printf "$i: "
				if hash $i 2>/dev/null; then
					echo -e "[\033[32mInstalled\033[0m]"
				else
					echo -e "[\033[31mNot found\033[0m]"
					missing=true
				fi
		  	done
			$missing && read -p "WARNING: You may want to install missing dependencies based on your plateform"
		  	cp -i $DIR/jarvis-config-default.sh $DIR/jarvis-config.sh
			cp -i $DIR/jarvis-commands-default $DIR/jarvis-commands
			read -p "Press [Enter] to edit the config file. Please follow instructions."
			nano $DIR/jarvis-config.sh
			echo "Installation complete."
			exit;;
        k)	keyboard=true;;
		q)	quiet=true;;
		r)	rm -i $audiofile $DIR/jarvis-config.sh $DIR/jarvis-commands; exit;;
		u)	cd $DIR
			git pull
			echo "Make sure there has been no change on default config files to replicate"
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

# Load config file
if [ ! -f $DIR/jarvis-config.sh ]; then
	echo "Missing config file. Install with command $>./jarvis -i" 1>&2
	exit 1
fi
source $DIR/jarvis-config.sh

# say wrapper to be used in jarvis-commands
say () { echo $trigger: $1; $quiet || TTS "$1"; }

handlecommand() {
	order=`echo $1 | iconv -f utf8 -t ascii//TRANSLIT | sed 's/[^a-zA-Z 0-9]//g'` # remove accents + osx hack http://stackoverflow.com/a/30832719	
	while read line; do
		pattern=${line%==*} # *MEANING*LIFE*==say 42 => *MEANING*LIFE*
		if [[ $order == $pattern ]]; then # WHAT IS THE MEANING OF LIFE ? == *MEANING*LIFE*
			action=${line#*==} # *MEANING*LIFE*==say 42 => say 42
			action="${action/.../${order#*REPETE}}"
			$verbose && echo "$> $action"
			
			bypass=false
			eval "$action" || say "$command_failed"
			$all_matches || return
		fi
	done < $DIR/jarvis-commands
	say "$unknown_command: $order"
}

say "$hello $username"
echo $byehelper
bypass=false
while true; do
	if [ $keyboard = true ]; then
		echo; echo $trigger: $welcome
		read -p "$username: " order
	else
		if [ $always_listening = false ]; then
			bypass=true
			read -p "Press [Enter] to start voice command"
		fi
		$trigger_mode && ! $bypass && echo "$trigger: Your order should include '$trigger'"
		echo "(listening until silence or press [Ctrl+C] to force stop...)"
		LISTEN $audiofile
		#$verbose && jplay $audiofile
		STT $audiofile
		echo "$username: $order"
		if $trigger_mode && ! $bypass && [[ "$order" != *$trigger* ]]; then
			PLAY $DIR/beep-error.wav
			continue
		fi
	fi
	[ -n "$order" ] && handlecommand "$order"
done
