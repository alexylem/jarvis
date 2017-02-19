#!/bin/bash
dialog_msg () { # usages
# dialog_msg "message"
# dialog_msg <<EOM
# line1
# line2
# EOM
    set -- "${1:-$(</dev/stdin)}" "${@:2}"
    osascript -e 'set front_app_name to short name of (info for (path to frontmost application))' -e "tell application front_app_name to display alert \"$1\"" >/dev/null
}

dialog_input () { # usage ask "question" "default"
    
    (( $? )) && echo "$2" || echo "$result"
}

dialog_input () { # usage dialog_input "question" "default" true
    local question="$1"
    local default="$2"
    local required="${3:-false}" # true / false (default)
    while true; do
        result="$(osascript -e "display dialog \"$question\" default answer \"$default\"" -e 'text returned of result' 2>/dev/null)" # don't put local or else return code always O
        if (( $? )); then
            echo "$default"
        elif [ -n "$result" ]; then # if not null
            echo "$result"
        elif $required; then
            continue
        fi
        return
    done
}

dialog_select () { # usage dialog_select "question" list[@] "default"
    declare -a list=("${!2}")
    list=$(printf ",\"%s\"" "${list[@]}")
    result=`osascript -e 'set front_app_name to short name of (info for (path to frontmost application))' -e "tell application front_app_name to choose from list {${list:1}} with prompt \"$1\" default items {\"$3\"}"`
    [ "$result" = false ] && echo "$3" || echo "$result"
}

dialog_menu () { # usage dialog_menu "question" list[@]
    declare -a list=("${!2}")
    first="${list[0]}"
    list=$(printf ",\"%s\"" "${list[@]}")
    osascript -e 'set front_app_name to short name of (info for (path to frontmost application))' -e "tell application front_app_name to choose from list {${list:1}} with title \"Jarvis\" with prompt \"$1\" default items {\"$first\"}"
}

dialog_yesno () { # usage dialog_yesno "question" default(true/false)
    default=`[ "$2" = "true" ] && echo 1 || echo 2`
    result=`osascript -e "display dialog \"$1\" buttons {\"Yes\", \"No\"} default button $default" -e "button returned of result"`
    if [ "$result" = "Yes" ]; then
        echo true
    else
        echo false
        return 1
    fi
}

editor () {
    dialog_msg "Make sure to Quit (cmd+Q) the Editor when finished"
    open -tW "$1"
    sed -i '' -e '$a\' "$1" # append new line if missing
}

# Public: install packages, used for dependencies
#
# args: list of packages to install
jv_install () {
    if ! hash brew 2>/dev/null; then
        if jv_yesno "You need Homebrew package manager, install it?"; then
            ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" < /dev/null 2> /dev/null
        fi
    fi
    brew install $@
}

# Public: open URL in default browser
jv_browse_url () {
    open "$1"
}
