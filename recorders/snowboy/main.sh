# record from microphone and save to audio file
# $1: audio file to record to
# $2: (optional) timeout in seconds
RECORD () {
    $verbose && local quiet='' || local quiet='>/dev/null 2>&1'
    [ -n "$2" ] && local timeout="utils/timeout.sh $2" || local timeout=""
    local cmd="$timeout python $quiet recorders/snowboy/main.py $gain $1 $quiet"
    $verbose && jv_debug "$cmd"
    printf $_gray
    eval $cmd # need eval because of timeout, maybe better to change this
    local retcode=$?
    printf $_reset
    [ $retcode -eq 124 ] && return 124 # timeout
    if [ "$retcode" -ne 0 ]; then
        jv_error "ERROR: rec command failed"
        jv_warning "HELP: retry in troubleshooting mode for more details"
        jv_exit 1
    fi
}
