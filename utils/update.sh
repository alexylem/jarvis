#!/bin/bash

# Internal: apply needed local config modifications following updates of Jarvis
jv_update_config () {    
    if [ "$jv_version" = "" ]; then
        printf "Applying updates of version 16.10.31..."
        [ "$(cat config/check_updates)" = "true" ] && echo "0" > config/check_updates
        jv_success "Done"
    fi
    if [[ "$jv_version" < "17.04.22" ]]; then
         printf "Applying updates of version 17.04.22..."
         mv plugins plugins_installed 2>/dev/null
         mkdir -p plugins_enabled
         plugins=$(ls plugins_installed)
         for plugin in $plugins; do
             jv_plugin_enable "$plugin"
         done
         jv_success "Done"
    fi
    
    # update complete, update local version
    jv_version="$(cat version.txt)"
    echo "$jv_version" > config/version
}
