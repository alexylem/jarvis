#!/bin/bash

# Public: version of Jarvis
jv_version="$(cat config/version 2>/dev/null)"

# Public: directory where Jarvis is installed without trailing slash
jv_dir="$jv_dir"

# Public: the name of the user
username=

# Public: the name of Jarvis (the hotword)
trigger=

# Public: the transcribed voice order
# 
#   *FAIT (*)==echo "capture: (1)"; echo "order: $order"
#   You: Fais le café
#   capture: le cafe
#   order: Fait le café 
order=

# Public: the user's language in Jarvis settings
#
# Ex: `en_GB`
# Use `${language:0:2}` to only get `en`
language=

# Public: user's platform (linux, osx)
platform=

# Public: user's architecture (armv7l, x86_64)
jv_arch=

# Public: user's OS name (raspbian, ubuntu, Mac OS X...)
jv_os_name=

# Public: user's OS version (8, 16.02, ...)
jv_os_version=

# Internal: indicates if there are nested commands
jv_possible_answers=false

# Public: indicates if called using API else normal usage
# 
#   $jv_api && echo "this is an API call"
jv_api=false

# Public: indicates if output should be in JSON
jv_json=false

# Public: ip address of Jarvis
# 
#   echo $jv_ip
#   192.168.1.20
jv_ip="$(/sbin/ifconfig | sed -En 's/127.0.0.1//;s/.*inet (ad[d]?r:)?(([0-9]*\.){3}[0-9]*).*/\2/p')"

# Internal: indicates if Jarvis is paused
jv_is_paused=false

# Internal: signal number of SIGUSR1 to pause / resume jarvis
jv_sig_pause=$(kill -l SIGUSR1)

# Internal: signal number of SIGUSR2 to trigger command mode
jv_sig_listen=$(kill -l SIGUSR2)

# Internal: indicats if jarvis has been updated to ask for restart
jv_jarvis_updated=false

# Internal: check if all dependencies are installed
jv_check_dependencies () {
    local missings=()
    for package in "${dependencies[@]}"; do
        jv_is_installed "$package" || missings+=($package)
    done
    if [ ${#missings[@]} -gt 0 ]; then
        jv_warning "You must install missing dependencies before going further"
        for missing in "${missings[@]}"; do
            echo "$missing: Not found"
        done
        jv_yesno "Attempt to automatically install the above packages?" || exit 1
        jv_update # split jv_update and jv_install to make overall jarvis installation faster
        jv_install ${missings[@]} || exit 1
    fi
    
    if [[ "$platform" == "linux" ]]; then
        if ! groups "$(whoami)" | grep -qw audio; then
            jv_warning "Your user should be part of audio group to list audio devices"
            jv_yesno "Would you like to add audio group to user $USER?" || exit 1
            sudo usermod -a -G audio $USER # add audio group to user
            jv_warning "Please logout and login for new group permissions to take effect, then restart Jarvis"
            exit
        fi
    fi
}

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
    message=${message//[$'\t']/    } # replace tabs with spaces
    message=${message//%/%%} # escape percentage chars for printf
    printf "$jv_json_separator{\"$1\":\"${message}\"}"
    jv_json_separator=","
}

# Internal: get list of user defined and plugins commands
jv_get_commands () {
    grep -v "^#" jarvis-commands
    while read; do
        cat plugins_enabled/$REPLY/${language:0:2}/commands 2>/dev/null
    done <plugins_order.txt
}

# Public: display available commands grouped by plugin name
jv_display_commands () {
    jv_info "User defined commands:"
    jv_debug "$(grep -v "^#" jarvis-commands | cut -d '=' -f 1 | pr -3 -l1 -t)"
    while read plugin_name; do
        jv_info "Commands from plugin $plugin_name:"
        jv_debug "$(cat plugins_enabled/$plugin_name/${language:0:2}/commands 2>/dev/null | cut -d '=' -f 1 | pr -3 -l1 -t)"
    done <plugins_order.txt
}

# Internal: add timestamps to log file
# 
#   script.sh | jv_add_timestamps >> file.log
jv_add_timestamps () {
    while IFS= read -r line; do
        echo "$(date) $line"
    done
}

# Public: Speak some text out loud
# $1 - text to speak
# 
#   $> say "hello world"
#   Jarvis: hello world
say () {
    #set -- "${1:-$(</dev/stdin)}" "${@:2}" # read commands if $1 is empty... #195
    local phrases="$1"
    phrases="$(echo -e "$phrases" | sed $'s/\xC2\xA0/ /g')" #574 remove non-breakable spaces
    #phrase="${phrase/\*/}" #TODO * char causes issues with google & OSX say TTS, looks like no longer with below icon
    jv_hook "start_speaking" "$phrases" #533
    while read -r phrase; do #591 can be multiline
        if $jv_json; then
            jv_print_json "answer" "$phrase" #564
        else
            echo -e "$_pink$trigger$_reset: $phrase"
        fi
        $quiet && break #602
        if $jv_api; then # if using API, put in queue
            if jv_is_started; then
                echo "$phrase" >> $jv_say_queue # put in queue (read by say.sh)
            else
                jv_error "ERROR: Jarvis is not running"
                jv_success "HELP: Start Jarvis using jarvis -b"
            fi
        else # if using Jarvis, speak synchronously
            $tts_engine'_TTS' "$phrase"
        fi
    done <<< "$phrases"
    jv_hook "stop_speaking"
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
# Returns return code of background task
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
    wait $1 2>/dev/null # get return code of background task in $?
    return $? # return return code of background task
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
        | sed "s/[^-a-zA-Z0-9 $replace_spaces_with]//g"
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
jv_error() { jv_message "$1" "error" "$_red" 1>&2 ;}
# Public: Displays a warning in yellow
# $1 - message to display
jv_warning() { jv_message "$1" "warning" "$_orange" ;}
# Public: Displays a success in green
# $1 - message to display
jv_success() { jv_message "$1" "success" "$_green" ;}
# Public: Displays an information in blue
# $1 - message to display
jv_info() { jv_message "$1" "info" "$_blue" ;}
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

# Internal: start Jarvis as a service
jv_start_in_background () {
    nohup jarvis -$($verbose && echo v)n 2>&1 | jv_add_timestamps >> jarvis.log &
    cat <<EOM
Jarvis has been launched in background

To view Jarvis output:
jarvis and select "View output"
To check if jarvis is running:
pgrep -laf jarvis.sh
To stop Jarvis:
jarvis and select "Stop Jarvis"

You can now close this terminal
EOM
}

# Internal: indicates if Jarvis is already running
jv_is_started () {
    [ -e $lockfile ] && kill -0 `cat $lockfile` 2>/dev/null
}

# Internal: Kill Jarvis if running in background
jv_kill_jarvis () {
    if [ -e $lockfile ]; then
        local pid=$(cat $lockfile) # process id of jarvis
        if kill -0 $pid 2>/dev/null; then
            # Trigger program exit hook
            #jv_hook "program_exit" #410 for some reason below kill TERM is not caught by jarvis. Need to trigger hook manually before
            
            # Kill jarvis group of processes
            #local gid=$(ps -p $pid -o pgid=)
            #kill -TERM -$(echo $gid)
            kill -TERM $pid #607
            echo "Jarvis has been terminated"
            return 0
        fi
    fi
    echo "Jarvis is not running"
    return 1
}

# Internal: trigger hooks
# $1 - hook name to trigger
# $@ - other arguments to pass to hook
jv_hook () {
    #$jv_api && return # don't trigger hooks from API #jarvis-api/issues/11
    local hook="$1"
    shift
    source hooks/$hook "$@" 2>/dev/null # user hook
    shopt -s nullglob
    for f in plugins_enabled/*/hooks/$hook; do source $f "$@"; done # plugins hooks
    shopt -u nullglob
}

# Internal: resume or pause Jarvis hotword recognition
jv_pause_resume () {
    if $jv_is_paused; then
        jv_is_paused=false
        jv_debug "resuming..."
    else
        jv_is_paused=true
        jv_debug "pausing..."
    fi
}

# Public: Exit properly jarvis
# $1 - Return code
#
# Returns nothing
jv_exit () {
    local return_code=${1:-0}
    
    # If using json formatting, terminate table
    $jv_json && echo "]"
    
    # reset font color (sometimes needed)
    $jv_api || echo -e $_reset
    
    # Trigger program exit hook if not from api call
    $jv_api || jv_hook "program_exit" $return_code
    
    # termine child processes (ex: HTTP Server from Jarvis API Plugin)
    local jv_child_pids="$(jobs -p)"
    if [ -n "$jv_child_pids" ]; then
        kill $(jobs -p) 2>/dev/null
    fi
    
    # make sure the lockfile is removed when we exit and then claim it
    #[ "$(cat $lockfile)" == $$ ] && rm -f $lockfile # to be tested further
    #[ "$just_execute" == false ] && rm -f $lockfile # https://github.com/alexylem/jarvis-api/issues/3
    exit $return_code
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
    local is_jarvis="$([ "$repo_name" == "jarvis" ] && echo "true" || echo "false")"
    local branch="$( $is_jarvis && echo "$jv_branch" || echo "master")"
    printf "Checking updates for $repo_name..."
	read < <( git fetch origin -q & echo $! ) # suppress bash job control output
    jv_spinner $REPLY
	case $(git rev-list HEAD...origin/$branch --count || echo e) in
		"e") jv_error "Error";;
		"0") jv_success "Up-to-date";;
		*)	 jv_warning "New version available"
             changes=$(git fetch -q 2>&1 && git log HEAD..origin/$branch --oneline --format="- %s (%ar)" | head -5)
             if $force || dialog_yesno "A new version of $repo_name is available, recent changes:\n$changes\n\nWould you like to update?" true >/dev/null; then
				 # display recent commits in non-interactive mode
                 $force && echo -e "Recent changes:\n$changes"
                 
                 #git reset --hard HEAD >/dev/null # don't override local changes (config.sh)
            	 
                 local jv_config_changed=false
                 if $is_jarvis; then
                     # inform jarvis is updated to ask for restart
                     jv_jarvis_updated=true
                 elif [ 1 -eq $(git diff --name-only ..origin/master config.sh | wc -l) ]; then
                     # save user configuration if config.sh file changed on repo (only for plugins)
                     jv_config_changed=true
                     mv config.sh config.sh.old # save user config
                 fi
                 
                 # pull changes from repo
                 printf "Updating $repo_name..."
                 read < <( git pull -q & echo $! ) # suppress bash job control output
                 jv_spinner $REPLY
                 [ -f update.sh ] && source update.sh # source new updated file from git
            	 jv_success "Done"
                 
                 # if config changed, merge with user configuration and open in editor
                 if $jv_config_changed; then
                     sed -i.old -e 's/^/#/' config.sh.old # comment out old config file
                     echo -e "\n#Your previous config below (to copy from)" >> config.sh
                     cat config.sh.old >> config.sh # and append to new config file (for reference)
                     rm -f *.old # remove temp files
                     if $force; then
                         jv_warning "Config file has changed, reset your variables"
                     else
                         dialog_msg "Config file has changed, reset your variables"
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
    shopt -s nullglob
    for plugin_dir in plugins_installed/*; do
        jv_check_updates "$plugin_dir" "$1"            
    done
    shopt -u nullglob
}

# Internal: Rebuild plugins_order.txt following added/removed plugins
jv_plugins_order_rebuild () {
    # Append new plugins to plugins_order
    cat plugins_order.txt <( ls plugins_enabled ) 2>/dev/null | awk '!x[$0]++' > /tmp/plugins_order.tmp
    # Remove uninstalled plugins from plugins_order
    grep -xf <( ls plugins_enabled ) /tmp/plugins_order.tmp > plugins_order.txt
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

# Public: YesNo prompt from the command line
# 
# $1 - Question to be answered
#
# Usage
# 
#   $> jv_yesno "question?" && echo "Yup"
#   question? [Y/n] y
#   Yup
jv_yesno () {
    while true; do
        read -n 1 -p "$1 [Y/n] "
        echo # new line
        [[ $REPLY =~ [Yy] ]] && return 0
        [[ $REPLY =~ [Nn] ]] && return 1
    done
}

# Public: display a progress bar in the terminal
# $1 - current step number
# $2 - total number of steps
# 
# Usage (usually in a loop)
# 
#   $> jv_progressbar 5 10
#   [████████████████████                    ] 50%
#   $> jv_progressbar 10 10
#   [████████████████████████████████████████] 100%
jv_progressbar () {
    let _progress="(${1}*100/${2}*100)/100" # quotes to prevent globbing
	let _done="(${_progress}*4)/10" # quotes to prevent globbing
	let _left=40-$_done
	_done=$(printf "%${_done}s")
	_left=$(printf "%${_left}s")
    printf "\r${_done// /█}$_gray${_left// /█}$_reset ${_progress}%%"
}

# Internal: Build Jarvis
#
# Returns nothing
jv_build () {
    echo "Running tests..."
        roundup test/*.sh || exit 1
    printf "Updating version file..."
        date +"%y.%m.%d" > version.txt
        jv_success "Done"
    printf "Generating documentation..."
        utils/tomdoc.sh --markdown --access Public utils/utils.sh utils/utils_linux.sh > docs/api-reference-public.md
        utils/tomdoc.sh --markdown utils/utils.sh utils/utils_linux.sh > docs/api-reference-internal.md
        jv_success "Done"
    printf "Opening GitHub Desktop..."
        open -a "GitHub Desktop" /Users/alex/Documents/jarvis
        jv_success "Done"
}
