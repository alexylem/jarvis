#!/bin/bash
store_init () {
    if [ -f "$jv_store_file" ]; then
        jv_warning "Using cache, update to get new plugins"
    else
        jv_store_update
    fi
    #export store_json="$(curl -s http://openjarvis.com/all.json)" # why export?
    #export store_json_lower="$(echo "$store_json" | tr '[:upper:]' '[:lower:]')"
}

jv_store_update () {
    printf "Retrieving plugins database..."
    curl -s "https://www.openjarvis.com/all.json" -H 'User-Agent: Mozilla/5; Windows NT 5.1; en-US; rv:1.8.1.13) Gecko/20080311 Firefox/2.0.0.13' > "$jv_store_file" #617
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
    cat "$jv_store_file" | jq --raw-output ".nodes | sort_by(.node."$1") | reverse | .[:$2] | .[] | .node.title"
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

jv_store_create_plugin () {
    # ask github username first as user may not have it to proceed later
    local username="$(dialog_input "Your github username? sign-up at https://github.com/join")"
    [ -z "$username" ] && return
    local reponame="jarvis-"
    while true; do
        reponame="$(dialog_input "Your plugin name (short and self-explanatory)\nex: jarvis-cookbook" "$reponame")"
        reponame="$(jv_sanitize "$reponame" "-")" # sanitize special chars
        [[ "$reponame" == jarvis-* ]] || reponame="jarvis-$reponame" # make sure plugin name starts with jarvis-
        dialog_yesno "Your repository name will be: $reponame\nConfirm?" true >/dev/null && break
    done
    if [ -d "plugins_installed/$reponame" ]; then
        jv_error "folder plugins_installed/$reponame already exists"
        jv_press_enter_to_continue
        return 1
    fi
    local description="$(dialog_input "Optional short description for your github repository\nex: Plugin for Jarvis to give random recipies")"
    retcode="$(curl "https://api.github.com/user/repos" \
         --user "$username" \
         --progress-bar \
         --data "{\"name\":\"$reponame\",\"description\":\"$description\",\"has_issues\":true}" \
         --write-out "%{http_code}" \
         --output $jv_cache_folder/github.json)"
    if [ "${retcode:0:1}" != "2" ]; then
        jv_error "$(cat $jv_cache_folder/github.json)"
        jv_press_enter_to_continue
        return 1
    fi
    mkdir "plugins_installed/$reponame"
    cd "plugins_installed/$reponame"
    git clone "https://github.com/alexylem/jarvis-plugin" .
    git remote remove origin
    git remote add origin git@github.com:$username/$reponame.git
    git push --set-upstream origin master
    cd ../../
    jv_plugin_enable "$reponame"
    dialog_msg <<EOM
Congratulations, your plugin is now initialized and linked to your github account
To help you develop, commit and register your plugin on Jarvis store, visit:
http://openjarvis.com/content/publish-your-plugin
EOM
}
