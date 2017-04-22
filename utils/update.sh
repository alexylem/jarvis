#!/bin/bash

# Internal: apply needed local config modifications following updates of Jarvis 
if [ "$jv_version" = "" ]; then
    printf "Applying updates of version 16.10.31..."
    [ "$(cat config/check_updates)" = "true" ] && echo "0" > config/check_updates
    jv_success "Done"
fi
#if [[ "$jv_version" < "17.04.22" ]]; then
#     printf "Applying updates of version 17.04.22..."
#     jv_success "Done"
#fi

# update complete, update local version
jv_version="$(cat version.txt)"
echo "$jv_version" > config/version
