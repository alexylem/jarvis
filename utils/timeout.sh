#!/bin/sh

# Execute a command with a timeout

# License: LGPLv2
# Author:
#    http://www.pixelbeat.org/
# Notes:
#    Note there is a timeout command packaged with coreutils since v7.0
#    If the timeout occurs the exit status is 124.
#    There is an asynchronous (and buggy) equivalent of this
#    script packaged with bash (under /usr/share/doc/ in my distro),
#    which I only noticed after writing this.
#    I noticed later again that there is a C equivalent of this packaged
#    with satan by Wietse Venema, and copied to forensics by Dan Farmer.
# Changes:
#    V1.0, Nov  3 2006, Initial release
#    V1.1, Nov 20 2007, Brad Greenlee <brad@footle.org>
#                       Make more portable by using the 'CHLD'
#                       signal spec rather than 17.
#    V1.3, Oct 29 2009, Ján Sáreník <jasan@x31.com>
#                       Even though this runs under dash,ksh etc.
#                       it doesn't actually timeout. So enforce bash for now.
#                       Also change exit on timeout from 128 to 124
#                       to match coreutils.
#    V2.0, Oct 30 2009, Ján Sáreník <jasan@x31.com>
#                       Rewritten to cover compatibility with other
#                       Bourne shell implementations (pdksh, dash)

if [ "$#" -lt "2" ]; then
    echo "Usage:   `basename $0` timeout_in_seconds command" >&2
    echo "Example: `basename $0` 2 sleep 3 || echo timeout" >&2
    exit 1
fi

cleanup()
{
    trap - ALRM               #reset handler to default
    kill -ALRM $a 2>/dev/null #stop timer subshell if running
    kill $! 2>/dev/null &&    #kill last job
    exit 124                  #exit with 124 if it was running
}

watchit()
{
    trap "cleanup" ALRM
    sleep $1& wait
    kill -ALRM $$
}

watchit $1& a=$!         #start the timeout
shift                    #first param was timeout for sleep
trap "cleanup" ALRM INT  #cleanup after timeout
"$@"& wait $!; RET=$?    #start the job wait for it and save its return value
kill -ALRM $a            #send ALRM signal to watchit
wait $a                  #wait for watchit to finish cleanup
exit $RET                #return the value
