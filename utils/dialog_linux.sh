#!/bin/bash
dialog_msg () { # usages
# dialog_msg "message"
# dialog_msg <<EOM
# line1
# line2
# EOM
    set -- "${1:-$(</dev/stdin)}" "${@:2}"
    whiptail --msgbox "$1" 20 76
}

dialog_input () { # usage dialog_input "question" "default"
    # don't put local or else return code always O
    result=$(whiptail --inputbox "$1" 20 76 "$2" 3>&1 1>&2 2>&3)
    (( $? )) && echo "$2" || echo "$result"
}

dialog_select () { # usage dialog_select "question" list[@] "default"
    declare -a list=("${!2}")
    local nb=${#list[@]}
    local items=""
    for item in "${list[@]}"; do
        items="$items $item `[ "$item" = "$3" ] && echo "ON" || echo "OFF"` "
    done
    # don't put local or else return code always O
    result=`whiptail --radiolist "$1\n(Press space to Select, Enter to validate)" --noitem 20 76 $nb $items 3>&1 1>&2 2>&3`
    (( $? )) && echo "$3" || echo "$result"
}

dialog_menu () { # usage dialog_menu "question" list[@]
    declare -a list=("${!2}")
    local nb=${#list[@]}
    local items=()
    for item in "${list[@]}"; do
        items+=("" "$item")
    done
    whiptail --title "Jarvis" --menu "$1" 20 76 $nb "${items[@]}" 3>&1 1>&2 2>&3
}

dialog_yesno () { # usage dialog_yesno "question" default(true/false)
    whiptail --yesno "$1" 20 76 3>&1 1>&2 2>&3
    case $? in
        0) result=true;;
        1) result=false;;
        255) result="$2";;
    esac
    echo "$result"
    [ "$result" = false ] && return 1
    return 0
}
