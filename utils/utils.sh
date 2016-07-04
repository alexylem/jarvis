#!/bin/bash
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

settimeout() { ( set +b; sleep "$1" & "${@:2}" & wait -n; r=$?; kill -TERM `jobs -p`; exit $r; ) }

#settimeout () { # usage settimeout 10 command args
#	local timeout=$1
#    local retcode=0
#	shift
#	( $@ ) & pid=$!
#	( sleep $timeout && echo "rec timeouted" && kill -TERM $pid ) 2>/dev/null & watcher=$!
#	wait $pid 2>/dev/null && retcode=$? && echo "rec finished with $retcode" && pkill -HUP -P $watcher
#    echo "returning code $retcode"
#    return $retcode
#}
