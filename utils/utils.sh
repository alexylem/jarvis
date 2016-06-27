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

settimeout () { # usage settimeout 10 command args
	local timeout=$1
	shift
	( $@ ) & pid=$!
	( sleep $timeout && kill -HUP $pid ) 2>/dev/null & watcher=$!
	wait $pid 2>/dev/null && pkill -HUP -P $watcher
}
