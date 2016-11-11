#!/bin/bash

# Public: version of Jarvis
jv_version=$(cat version.txt)

# Public: the name of the user
username=

# Public: the name of Jarvis (the hotword)
trigger=

# Public: the transcribed voice order
order=

# Public: the user's language in Jarvis settings
#
# Ex: `en_GB`
# Use `${language:0:2}` to only get `en`
language=

# Public: Re-run last executed command. Use to create an order to repeat.
#
# Usage:
#
#   AGAIN*==jv_repeat_last_command
jv_repeat_last_command () {
    eval "$jv_last_command"
}

jv_json_separator=""

# Internal: Print JSON key value pair
# $1 - key
# $2 - value
jv_print_json () {
    message=${2//\"/\\\\\"} # escape double quotes
    message=${message//%/%%} # escape percentage chars for printf
    printf "$jv_json_separator{\"$1\":\"${message}\"}"
    jv_json_separator=","
}

# Public: display available commands grouped by plugin name
jv_display_commands () {
    jv_message "User defined commands:" 'category' $_cyan
    jv_debug "$(cat jarvis-commands | cut -d '=' -f 1 | pr -3 -l1 -t)"
    cd plugins/
    for plugin_name in *; do
        jv_message "Commands from plugin $plugin_name:" 'category' $_cyan
        jv_debug "$(cat $plugin_name/${language:0:2}/commands | cut -d '=' -f 1 | pr -3 -l1 -t)"
    done
    cd ../
}

# Public: Speak some text out loud 
# $1 - text to speak
# 
# Returns nothing
# 
#   $> say "hello world"
#   Jarvis: hello world
say () {
    #set -- "${1:-$(</dev/stdin)}" "${@:2}" # read commands if $1 is empty... #195
    if $jv_json; then
        jv_print_json "$trigger" "$1"
    else
        echo -e "$_pink$trigger$_reset: $1"
    fi
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

# Public: XML Parser
# 
# Usage:
#
#   while jv_read_dom; do
#     [[ $ENTITY = "tagname" ]] && echo $CONTENT
#   done < file.xml
jv_read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
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

# Internal: Display a message in color
# $1 - message to display
# $2 - message type (error/warning/success/debug)
# $3 - color to use
jv_message() {
    if $jv_json; then
        jv_print_json "$2" "$1"
    else
        echo -e "$3$1$_reset"
    fi
}
# Public: Displays a error in red
# $1 - message to display
jv_error() { jv_message "$1" "error" "$_red" ;}
# Public: Displays a warning in yellow
# $1 - message to display
jv_warning() { jv_message "$1" "warning" "$_orange" ;}
# Public: Displays a success in green
# $1 - message to display
jv_success() { jv_message "$1" "success" "$_green" ;}
# Public: Displays a log in gray
# $1 - message to display
jv_debug() { jv_message "$1" "debug" "$_gray" ;}

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
    # termine child processes (ex: HTTP Server from Jarvis API Plugin)
    local jv_child_pids="$(jobs -p)"
    if [ -n "$jv_child_pids" ]; then
        kill $(jobs -p) 2>/dev/null
    fi
    # make sure the lockfile is removed when we exit and then claim it
    $jv_json && printf "]"
    echo # new line
    rm -f $lockfile
    exit $1
}
    
# Internal: check updates and pull changes from github
# $1 - path of git folder to check, default current dir
# $2 - don't ask confirmation, default false
jv_check_updates () {
    local initial_path="$(pwd)"
    local repo_path="${1:-.}" # . default value if $1 is empty (current dir)
    local force=${2:-false} # false default value if $2 is empty
    cd "$repo_path"
    local repo_name="$(basename $(pwd))"
    printf "Checking updates for $repo_name..."
	read < <( git fetch origin -q & echo $! ) # suppress bash job control output
    jv_spinner $REPLY
	case `git rev-list HEAD...origin/master --count || echo e` in
		"e") jv_error "Error";;
		"0") jv_success "Up-to-date";;
		*)	 jv_warning "New version available"
             changes=$(git fetch -q 2>&1 && git log HEAD..origin/master --oneline --format="- %s (%ar)" | head -5)
             if $force || dialog_yesno "A new version of $repo_name is available, recent changes:\n$changes\n\nWould you like to update?" true >/dev/null; then
				 # display recent commits in non-interactive mode
                 $force && echo -e "Recent changes:\n$changes"
                 
                 #git reset --hard HEAD >/dev/null # don't override local changes (config.sh)
            	 
                 # save user configuration if config.sh file changed on repo (only for plugins)
                 local jv_config_changed=false
                 if [ -e config.sh ] && [ 1 -eq $(git diff --name-only ..origin/master config.sh | wc -l) ]; then
                     jv_config_changed=true
                     mv config.sh user-config.sh.old # save user config
                 fi
                 
                 # pull changes from repo
                 printf "Updating $repo_name..."
                 read < <( git pull -q & echo $! ) # suppress bash job control output
                 jv_spinner $REPLY
            	 jv_success "Done"
                 
                 # if config changed, merge with user configuration and open in editor
                 if $jv_config_changed; then
                     sed -i.old -e 's/^/#/' config.sh # comment out new config file
                     cat user-config.sh.old >> config.sh # append saved user config
                     rm -f *.old # remove temp files
                     if $force; then
                         jv_warning "Config file has changed, check new variables"
                     else
                         dialog_msg "Config file has changed, check new variables"
                         editor "config.sh"
                     fi
                 fi
			 fi
			 ;;
	esac
    cd "$initial_path"
}

# Internal: runs jv_check_updates for all plugins
# $1 - don't ask confirmation, default false
jv_plugins_check_updates () {
    cd plugins/
    shopt -s nullglob
    for plugin_dir in *; do
        jv_check_updates "$plugin_dir" "$1"            
    done
    shopt -u nullglob
    cd ../
}

# Internal: send hit to Google Analytics on /jarvis.sh
# This is to anonymously evaluate the global usage of Jarvis app by users
# 
# Run asynchrously to avoid slowdown
#
#   $> ( jv_ga_send_hit & )
jv_ga_send_hit () {
    local tid="UA-29589045-1"
    if [ -f config/uuid ]; then
        local cid=$(cat config/uuid)
    else
        [[ $OSTYPE = darwin* ]] && local cid=$(uuidgen) || local cid=$(cat /proc/sys/kernel/random/uuid)
        echo "$cid" > config/uuid
    fi
    local data="v=1"
    data+="&t=pageview"
    data+="&tid=$tid"
    data+="&cid=$cid"
    data+="&dp=%2Fjarvis.sh"
    data+="&ds=app" # data source
    data+="&ul=$language" # user language
    data+="&an=Jarvis" # application name
    data+="&av=$jv_version" # application version
    curl -s -o /dev/null --data "$data" "http://www.google-analytics.com/collect"
}

# Internal: Build Jarvis
#
# Returns nothing
jv_build () {
    printf "Updating version file..."
        date +"%y.%m.%d" > version.txt
        jv_success "Done"
    printf "Generating documentation..."
        utils/tomdoc.sh --markdown --access Public utils/utils.sh > docs/api-reference-public.md
        utils/tomdoc.sh --markdown utils/utils.sh utils/update.sh > docs/api-reference-internal.md
        jv_success "Done"
    printf "Opening GitHub Desktop..."
        open -a "GitHub Desktop" /Users/alex/Documents/jarvis
        jv_success "Done"
}
