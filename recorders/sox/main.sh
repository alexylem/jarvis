# record from microphone and save to audio file
# $1: audio file to record to
# $2: (optional) timeout in seconds
RECORD () {
    [ -n "$2" ] && local timeout="utils/timeout.sh $2" || local timeout=""
    [ $platform = "linux" ] && export AUDIODRIVER=alsa
    local cmd="$timeout rec -V1 -q -r 16000 -c 1 -b 16 -e signed-integer --endian little $1 gain $gain silence 1 $min_noise_duration_to_start $min_noise_perc_to_start 1 $min_silence_duration_to_stop $min_silence_level_to_stop pad 0.5 0.5 trim 0 5"
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
