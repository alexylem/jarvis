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
    result=`osascript -e "display dialog \"$1\" default answer \"$2\""  -e 'text returned of result' 2>/dev/null`
    (( $? )) && echo "$2" || echo "$result"
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
