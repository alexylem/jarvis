#!/bin/bash

# Public: Speak some text out loud 
# 
# $1 - text to speak
# 
#   $> say "hello world"
#   OR
#   $> echo hello world | say
#   Jarvis: hello world
say () {
    set -- "${1:-$(</dev/stdin)}" "${@:2}"
    echo -e "$_pink$trigger$_reset: $1"; $quiet || TTS "$1";
}

# Public: Displays a spinner for long running commmands
# 
#   command &; jv_spinner $!
#   |/-\|\-\... (spinning bar)
jv_spinner () {
	while kill -0 $1 2>/dev/null; do
		for i in \| / - \\; do
			printf '%c\b' $i
			sleep .1
		done
	done
}

# Internal: Updates alsa user config at ~/.asoundrc
#
# $1 - play_hw
# $2 - rec_hw
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

# Public: Rremoves accents, lowercase, strip special chars and optionally replace spaces
# with underscores
# 
# $1 - (required) string to sanitize
# $2 - (optional) character to replace spaces with
# 
#   $> jv_sanitize "Caractères Spéciaux?"
#   caracteres speciaux
jv_sanitize () {
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

# Public: Displays a error in red
# $1 - message to display
jv_error() { echo -e "$_red$@$_reset" ;}
# Public: Displays a warning in yellow
# $1 - message to display
jv_warning() { echo -e "$_orange$@$_reset" ;}
# Public: Displays a success in green
# $1 - message to display
jv_success() { echo -e "$_green$@$_reset" ;}
# Public: Displays a log in gray
# $1 - message to display
jv_debug() { echo -e "$_gray$@$_reset" ;}

# Public: Asks user to press enter to continue
# 
#   $> jv_press_enter_to_continue
#   Press [Enter] to continue
jv_press_enter_to_continue () {
    jv_debug "Press [Enter] to continue"
    read
}

# Public: Exit properly jarvis
#
# $1 - Return code
jv_exit () {
    $verbose && jv_debug "DEBUG: program exit handler"
    source hooks/program_exit $1
    # make sure the lockfile is removed when we exit and then claim it
    rm -f $lockfile
    exit $1
}

# Internal: Build Jarvis
jv_build () {
    printf "Generating documentation..."
        utils/tomdoc.sh --markdown --access Public utils/utils.sh > docs/api-reference-public.md
        utils/tomdoc.sh --markdown utils/utils.sh > docs/api-reference-internal.md
        jv_success "[Done]"
    printf "Opening GitHub Desktop..."
        open -a "GitHub Desktop" /Users/alex/Documents/jarvis
        jv_success "[Done]"
}

# Public: Call HTTP requests
# 
# It displays errors if request fails
# When ran in troubleshooting mode, it will display request & response
# 
# $@ - all arguments you would give to curl
#
# Returns the return code of curl
#
#   $> *COMMAND*==jv_curl "http://192.168.1.1/action" && say "Done"
jv_curl () {
    local curl_command="curl --silent --fail --show-error $@"
    $verbose && jv_debug "DEBUG: $curl_command"
    response=$($curl_command 2>&1)
    local return_code=$?
    if [ $return_code -ne 0 ]; then
        jv_error "ERROR: $response"
    else
        $verbose && jv_debug "DEBUG: $response"
    fi
    return $return_code
}
