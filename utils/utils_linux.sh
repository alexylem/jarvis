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

dialog_input () { # usage dialog_input "question" "default" true
    local question="$1"
    local default="$2"
    local required="${3:-false}" # true / false (default)
    
    [ "${default:0:1}" == "-" ] && default=" $default" # https://github.com/alexylem/jarvis/issues/246#issuecomment-282426847
    
    while true; do
        result=$(whiptail --inputbox "$question" 20 76 "$default" 3>&1 1>&2 2>&3) # don't put local or else return code always O
        if (( $? )); then # cancel
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
    #echo "list=${list[@]}"
    local nb=${#list[@]}
    #echo "nb=$nb"
    local items=()
    for item in "${list[@]}"; do
        items+=("$item" "" $([[ "$item" == "$3"* ]] && echo "ON" || echo "OFF") )
    done
    #echo "items=${items[@]} (${#items[@]})"
    # don't put local or else return code always O
    result="$(whiptail --radiolist "$1\n(Press space to Select, Enter to validate)" 20 76 $nb "${items[@]}" 3>&1 1>&2 2>&3)"
    (( $? )) && echo "$3" || echo "$result" #549
}

dialog_menu () { # usage dialog_menu "question" list[@]
    declare -a list=("${!2}")
    local nb=${#list[@]}
    local items=()
    for item in "${list[@]}"; do
        items+=("$item" "")
    done
    whiptail --title "Jarvis" --menu "$1" 20 76 10 "${items[@]}" 3>&1 1>&2 2>&3
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

editor () {
    "${EDITOR:-nano}" "$1"
}

# Public: update package/formula list
# 
#   jv_update
jv_update () {
    sudo apt-get update -y #421
}

# Public: indicates if a package is installed
# 
# $1 - package to verify
# 
#   jv_is_installed mpg123 && echo "already installed"
jv_is_installed () {
    hash "$1" 2>/dev/null || dpkg -s "$1" >/dev/null 2>&1
}

# Public: install packages, used for dependencies
#
# $@ - list of packages to install
# 
#   jv_install mpg123
jv_install () {
    sudo apt-get install -y $@ && sudo apt-get clean
}

# Public: remove packages, used for uninstalls
#
# $@ - list of packages to remove
#
#   jv_remove mpg123
jv_remove () {
    sudo apt-get remove $@
}

# Public: open URL in default browser
jv_browse_url () {
    sensible-browser "$1"
}
