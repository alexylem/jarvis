#!/bin/bash
spinner(){ # usage: command &; spinner $!
	while kill -0 $1 2>/dev/null; do
		for i in \| / - \\; do
			printf '%c\b' $i
			sleep .1
		done
	done
}

update_alsa () { # usage: update_alsa $play_hw $rec_hw
    echo "Updating ~/.asoundrc..."
    cat<<EOM > ~/.asoundrc
pcm.!default {
  type asym
   playback.pcm {
     type plug
     slave.pcm "$1"
   }
   capture.pcm {
     type plug
     slave.pcm "$2"
   }
}
EOM
    echo "Reloading Alsa..."
    sudo /etc/init.d/alsa-utils restart
}

jv_sanitize () {
    # removes accents, lowercase, strip special chars and optionally replace spaces with underscores
    # $1 (required) string to sanitize
    # $2 (optional) character to replace spaces with
    local string="$1"
    local replace_spaces_with="$2"
    
    # replace spaces by _ if user requested
    [[ -n "$replace_spaces_with" ]] && string=${string// /$replace_spaces_with}
    
    # lowercase, remove accents and strip special chars http://stackoverflow.com/a/30832719
    echo $string \
        | tr '[:upper:]' '[:lower:]' \
        | iconv -f utf-8 -t ascii//TRANSLIT \
        | sed "s/[^a-zA-Z0-9 $replace_spaces_with]//g"
}

_reset="\033[0m"
_red="\033[91m"
_orange="\033[93m"
_green="\033[92m"
_gray="\033[2m"
_blue="\033[94m"
_cyan="\033[96m"
_pink="\033[95m"

my_error() { echo -e "$_red$@$_reset" ;}
my_warning() { echo -e "$_orange$@$_reset" ;}
my_success() { echo -e "$_green$@$_reset" ;}
my_debug() { echo -e "$_gray$@$_reset" ;}

press_enter_to_continue () {
    my_debug "Press [Enter] to continue"
    read
}
