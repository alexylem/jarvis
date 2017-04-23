store_init () {
    if [ -f "$jv_store_file" ]; then
        echo "Using cache, update to get new plugins"
    else
        jv_store_update
    fi
    #export store_json="$(curl -s http://domotiquefacile.fr/jarvis/all.json)" # why export?
    #export store_json_lower="$(echo "$store_json" | tr '[:upper:]' '[:lower:]')"
}

jv_store_update () {
    printf "Retrieving plugins database..."
    curl -s "http://domotiquefacile.fr/jarvis/all.json" > "$jv_store_file"
    jv_success "Done"
}

store_get_nb_plugins () {
    cat "$jv_store_file" | jq '.nodes | length'
}

store_get_categories () {
    #echo "$store_json" | jq -r '.nodes | unique_by(.node.category) | sort_by(.node.category) | .[].node.category'
    echo "All
GUI
Home Automation
Information
Media
Productivity
Social
System"
}

# Internal: list $2 top plugins sorted by $1
jv_store_list_plugins_top () {
    cat "$jv_store_file" | jq --raw-output ".nodes | sort_by(.node.\"$1\") | reverse | limit($2;.[]) | .node.title"
}

# Internal: list plugins in category $1 (can be "All")
jv_store_list_plugins_category () {
    # build jq filter based on category selected
    local filter=".nodes"
    if [ "$1" != "All" ]; then
        filter="$filter | map(select(.node.category | contains(\"$1\")))"
    fi
    cat "$jv_store_file" | jq --raw-output "$filter | .[].node.title"
}

# Internal: list recommended plugins
jv_store_list_plugins_recommended () {
    cat "$jv_store_file" | jq --raw-output ".nodes | map(select(.node.recommended==\"Recommended\")) | .[].node.title"
}

jv_store_search_plugins () { # $1:space separated search terms
    # TODO test not available in jq 1.4 (raspbian)
    #echo "$store_json" | jq -r ".nodes[] | select(.node.body | test(\"$1\"; \"i\")) | .node.title"
    local term="$(jv_sanitize "$1")"
    cat "$jv_store_file" | jq -r ".nodes[] | select(.node.tags | contains(\"$term\")) | .node.title" #TODO create new keyword field on plugins?
}

store_get_field () { # $1:plugin_name, $2:field_name
    cat "$jv_store_file" | jq -r ".nodes | map(select(.node.title==\"$1\")) | .[0].node.$2"
}

store_get_field_by_repo () {
    cat "$jv_store_file" | jq -r ".nodes | map(select(.node.repo==\"$1\")) | .[0].node.$2"
}

store_display_readme () { # $1:plugin_url
    local plugin_readme_url="${plugin_url/github.com/raw.githubusercontent.com}/master/README.md"
    clear
    jv_debug "Loading..."
    curl -s "$plugin_readme_url" | sed '/<!--/,/-->/d' | more # strip comments
    jv_press_enter_to_continue
}

store_install_plugin () { # $1:plugin_url
    local plugin_name="${1##*/}" #extract repo_name from url
    cd plugins_installed
    git clone "$1.git" #https://github.com/alexylem/jarvis.git
    if [[ $? -eq 0 ]]; then
        cd "$plugin_name"
        source install.sh
        if [[ -s "config.sh" ]]; then
            dialog_msg "This plugin needs configuration"
            editor "config.sh"
        fi
        cd ../
        dialog_msg "Installation Complete"
    else
        jv_error "ERROR: An error has occured"
        jv_press_enter_to_continue
    fi
    cd ../
    jv_plugin_enable "$plugin_name"
    # jv_plugins_order_rebuild # in jv_plugin_enable
}

jv_plugin_is_enabled () {
    [ -d "plugins_enabled/$1" ]
}

jv_plugin_enable () {
    ln -s "$jv_dir/plugins_installed/$1" "plugins_enabled/$1"
    jv_plugins_order_rebuild
}

jv_plugin_disable () {
    rm "plugins_enabled/$1"
    jv_plugins_order_rebuild
}

store_plugin_uninstall () { # $1:plugin_name
    jv_plugin_is_enabled "$1" && jv_plugin_disable "$1"
    source "plugins_installed/$1/uninstall.sh" # access to jarvis variables
    rm -rf "plugins_installed/$1"
    #jv_plugins_order_rebuild # in jv_plugin_disable
    #cd plugins_installed/
}
