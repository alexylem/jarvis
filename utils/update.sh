#!/bin/bash

# Internal: apply needed local config modifications following updates of Jarvis
jv_update_config () {
    local jv_local_version="$(cat config/version 2>/dev/null)"
    
    if [ "$jv_local_version" = "" ]; then
        printf "Applying updates of version 16.10.31..."
        [ "$(cat config/check_updates)" = "true" ] && echo "0" > config/check_updates
        jv_success "Done"
    fi
    #if [ "$jv_local_version" < "XX.XX.XX"]; then
    #    printf "Applying updates of version XX.XX.XX..."
    #    jv_success "Done"
    #fi
    
    # update complete, update local version
    echo "$jv_version" > config/version
}
