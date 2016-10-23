#!/bin/bash

# Public: Speak some text out loud 
# $1 - text to speak
# 
# Returns nothing
# 
#   $> say "hello world"
#   OR
#   $> echo hello world | say
#   Jarvis: hello world
say () {
    set -- "${1:-$(</dev/stdin)}" "${@:2}"
    echo -e "$_pink$trigger$_reset: $1"
    $quiet || $tts_engine'_TTS' "$1"
}

# Public: Call HTTP requests
# 
# It displays errors if request fails
# When ran in troubleshooting mode, it will display request & response
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

# Public: Displays a spinner for long running commmands
# 
# Returns nothing
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
# $1 - (required) string to sanitize
# $2 - (optional) character to replace spaces with
# 
# Echoes the sanitized string
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
# Returns nothing
#
#   $> jv_press_enter_to_continue
#   Press [Enter] to continue
jv_press_enter_to_continue () {
    jv_debug "Press [Enter] to continue"
    read
}

# Public: Exit properly jarvis
# $1 - Return code
#
# Returns nothing
jv_exit () {
    $verbose && jv_debug "DEBUG: program exit handler"
    source hooks/program_exit $1
    # make sure the lockfile is removed when we exit and then claim it
    rm -f $lockfile
    exit $1
}
    
# Internal: check updates and pull changes from github
# $1 - path of git folder to check, default current dir
jv_check_updates () {
    local initial_path="$(pwd)"
    local repo_path="${1:-.}" # . default value if $1 is empty (current dir)
    cd "$repo_path"
    local repo_name="$(basename $(pwd))"
    printf "Checking updates for $repo_name..."
	read < <( git fetch origin -q & echo $! ) # suppress bash job control output
    jv_spinner $REPLY
	case `git rev-list HEAD...origin/master --count || echo e` in
		"e") echo -e "[\033[31mError\033[0m]";;
		"0") echo -e "[\033[32mUp-to-date\033[0m]";;
		*)	echo -e "[\033[33mNew version available\033[0m]"
            changes=$(git fetch -q 2>&1 && git log HEAD..origin/master --oneline --format="- %s (%ar)" | head -5)
            if dialog_yesno "A new version of $repo_name is available, recent changes:\n$changes\n\nWould you like to update?" false >/dev/null; then
				printf "Updating..."
                #git reset --hard HEAD >/dev/null # override any local change
            	git pull -q &
                jv_spinner $!
            	jv_success "Update completed"
			fi
			;;
	esac
    cd "$initial_path"
}

# Internal: runs jv_check_updates for all plugins
jv_plugins_check_updates () {
    cd plugins/
    shopt -s nullglob
    for plugin_dir in *; do
        jv_check_updates "$plugin_dir"            
    done
    shopt -u nullglob
    cd ../
}

# Internal: Build Jarvis
#
# Returns nothing
jv_build () {
    printf "Generating documentation..."
        utils/tomdoc.sh --markdown --access Public utils/utils.sh > docs/api-reference-public.md
        utils/tomdoc.sh --markdown utils/utils.sh > docs/api-reference-internal.md
        jv_success "[Done]"
    printf "Opening GitHub Desktop..."
        open -a "GitHub Desktop" /Users/alex/Documents/jarvis
        jv_success "[Done]"
}
