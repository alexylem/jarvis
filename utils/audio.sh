# Audio related functions for Jarvis

# play an audio file to speakers
# $1: audio file to play
jv_play () {
    [ $platform = "linux" ] && local play_export="AUDIODRIVER=alsa" || local play_export=''
    eval "$play_export play -V1 -q $1"
    if [ "$?" -ne 0 ]; then
        jv_error "ERROR: play command failed"
        jv_warning "HELP: Verify your speaker in Settings > Audio > Speaker"
        jv_exit 1
    fi
}

<<<<<<< HEAD:utils/audio.sh
=======
RECORD () { # RECORD () {} record microhphone to audio file $1 when sound is detected until silence
    $verbose && local quiet='' || local quiet='-d'
    [ -n "$2" ] && local timeout="utils/timeout.sh $2" || local timeout=""
    [ $platform = "linux" ] && export AUDIODRIVER=alsa
    local cmd="$timeout rec -V1 -q -r 16000 -c 1 -b 16 -e signed-integer --endian little $1 gain $gain silence 1 $min_noise_duration_to_start $min_noise_perc_to_start 1 $min_silence_duration_to_stop $min_silence_level_to_stop trim 0 5"
    $verbose && jv_debug "$cmd"
    eval $cmd # need eval because of timeout, maybe better to change this
    local retcode=$?
    [ $retcode -eq 124 ] && return 124 # timeout
    if [ "$retcode" -ne 0 ]; then
        jv_error "ERROR: rec command failed"
        jv_warning "HELP: Verify your mic in Settings > Audio > Mic"
        jv_exit 1
    fi
}

>>>>>>> origin/pr/478:jarvis-functions.sh
jv_record_duration () {
    local audiofile=$1
    local duration=$2
    rec $audiofile gain $gain trim 0.5 $duration # skip first 0.5 secs due to mic activation noise
    if [ "$?" -ne 0 ]; then
        jv_error "ERROR: rec command failed"
        jv_warning "HELP: Verify your mic in Settings > Audio > Mic"
        jv_exit 1
    fi
}

jv_auto_levels () {
    local max_silence_level=5
    local min_voice_level=50
    local max_voice_level=95
    
    dialog_msg <<EOM
The following steps will automatically adjust your audio levels to best suit your microphone sensitivity and environment noise.
EOM
    while true; do
        
        while true; do
            dialog_msg <<EOM
Automatic setup of silence level.
1) Make SILENCE in the room (no TV, Music...)
2) Click OK
3) DO NOT SPEAK (will last 3 seconds)
EOM
            clear
            jv_record_duration $audiofile 3
            local silence_level="$(( 10#$(sox $audiofile -n stats 2>&1 | sed -n 's#^Max level[^0-9]*\([0-9]*\).\([0-9]\{0,2\}\).*#\1\2#p') ))"
            
            if [ $silence_level -le $max_silence_level ]; then
                break
            else
                options=("Retry (recommended first)"
                         "Decrease microphone gain"
                         "Skip")
                case "$(dialog_menu "Oups! Your silence level ($silence_level%) is above $max_silence_level%" options[@])" in
                    Retry*)     continue;;
                    Decrease*)  configure "gain"
                                continue 2
                                ;;
                    Skip)       dialog_msg "You can auto-adjust later in Settings > Audio"
                                return 1
                                ;;
                esac
            fi
        done
        
        while true; do
            dialog_msg <<EOM
Automatic setup of voice level.
1) Click OK
2) Get to a reasonable distance from the microphone
3) Speak NORMALLY (for 3 seconds)
EOM
            clear
            jv_record_duration $audiofile 3
            local voice_level="$(( 10#$(sox $audiofile -n stats 2>&1 | sed -n 's#^Max level[^0-9]*\([0-9]*\).\([0-9]\{0,2\}\).*#\1\2#p') ))"
            
            if [ $voice_level -lt $min_voice_level ]; then
                options=("Retry and speak louder/closer (recommended first)"
                         "Increase microphone gain"
                         "Skip")
                case "$(dialog_menu "Oups! Your voice volume ($voice_level%) is below $min_voice_level%" options[@])" in
                    Retry*)     continue;;
                    Increase*)  configure "gain"
                                continue 2
                                ;;
                   Skip)        dialog_msg "You can auto-adjust later in Settings > Audio"
                                return 1
                                ;;
                esac
            elif [ $voice_level -gt $max_voice_level ]; then
                options=("Retry and speak lower (recommended first)"
                         "Decrease microphone gain"
                         "Exit")
                case "$(dialog_menu "Oups! Your voice volume ($voice_level%) is above $max_voice_level%" options[@])" in
                    Retry*) continue;;
                    Decrease*) configure "gain"
                               continue 2
                               ;;
                    Exit) return 1;;
                esac
            else
                break
            fi
        done
        break
    done
    
    local sox_level=$(( $silence_level*2+1 ))
    min_noise_perc_to_start=$sox_level
    min_silence_level_to_stop=$sox_level
    #configure "save" #done when exiting settings menu / completing wizard
    
    dialog_msg <<EOM
Results:
- Silence level: $silence_level% (max $max_silence_level%)
- Voice volume: $voice_level% (min $min_voice_level%, max $max_voice_level%)
Sox parameters:
- Microphone gain: $gain
- Min noise percentage to start: $min_noise_perc_to_start%
- Min silence percentage to stop: $min_silence_level_to_stop%
EOM
}

LISTEN_COMMAND () {
    RECORD "$audiofile" 10
    [ $? -eq 124 ] && return 124
    
    duration=$(sox $audiofile -n stat 2>&1 | sed -n 's#^Length[^0-9]*\([0-9]*\).\([0-9]\)*$#\1\2#p')
    $verbose && jv_debug "DEBUG: speech duration was $duration (10 = 1 sec)"
    if [ "$duration" -gt 40 ]; then
        if $verbose; then
            jv_warning "WARNING: too long for a command (max 4 secs), ignoring..."
            jv_warning "HELP: try in order the following options"
            jv_warning "1) wait longer between voice commands"
            jv_warning "2) reduce ambiant background noise"
            jv_warning "3) decrease mic sensitivity in Settings > Audio"
            jv_warning "4) increase Min Silence Level to Stop"
        else
            printf '#'
        fi
        sleep 1 # https://github.com/alexylem/jarvis/issues/32
        return 1
    fi
}

LISTEN_TRIGGER () {
    while true; do
        RECORD "$audiofile"
        duration=`sox $audiofile -n stat 2>&1 | sed -n 's#^Length[^0-9]*\([0-9]*\).\([0-9]\)*$#\1\2#p'`
        $verbose && jv_debug "DEBUG: speech duration was $duration (10 = 1 sec)"
        if [ "$duration" -lt 2 ]; then
            $verbose && jv_debug "DEBUG: too short for a trigger (min 0.2 max 1.5 sec), ignoring..." || printf '-'
            continue
        elif [ "$duration" -gt 20 ]; then
            $verbose && jv_debug "DEBUG: too long for a trigger (min 0.5 max 1.5 sec), ignoring..." || printf '#'
            sleep 1 # BUG 
            continue
        else
            break
        fi
    done
}

# Calls appropriate voice record function depending on conversation mode
LISTEN () {
    local returncode=0
    if $bypass; then
        jv_hook "start_listening"
        LISTEN_COMMAND
        returncode=$?
        jv_hook "stop_listening"
    else
        LISTEN_TRIGGER
        returncode=$?
    fi
    $verbose && jv_play "$audiofile"
    return $returncode
}
