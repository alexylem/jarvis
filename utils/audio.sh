#!/bin/bash
# Audio related functions for Jarvis

# Public: play an audio file to speakers  
# $1: audio file to play
jv_play () {
    [ "$platform" = "linux" ] && local play_export="AUDIODRIVER=alsa" || local play_export='' # is this still needed?
    [ -s "$1" ] && eval "$play_export play -V1 -q $1 tempo $tempo" #591 sox bug with empty audio files
    if [ "$?" -ne 0 ]; then
        jv_error "ERROR: play command failed"
        jv_warning "HELP: Verify your speaker in Settings > Audio > Speaker"
        jv_exit 1
    fi
}

# Internal: record audio file for specific duration
#
# $1: audiofile
# $2: duration in seconds
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

# Internal: auto-adjust audio levels
jv_auto_levels () {
    local max_silence_level=5
    local min_voice_level=30
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
    
    local sox_level="$(perl -e "print $silence_level*2+0.1")"
    min_noise_perc_to_start="$sox_level%"
    min_silence_level_to_stop="$sox_level%"
    #configure "save" #done when exiting settings menu / completing wizard
    
    dialog_msg <<EOM
Results:
- Silence level: $silence_level% (max $max_silence_level%)
- Voice volume: $voice_level% (min $min_voice_level%, max $max_voice_level%)
Sox parameters:
- Microphone gain: $gain
- Min noise percentage to start: $min_noise_perc_to_start
- Min silence percentage to stop: $min_silence_level_to_stop
EOM
}

LISTEN_COMMAND () {
    RECORD "$audiofile" "$jv_timeout"
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
    if $verbose && [ $returncode -eq 0 ]; then #508
        jv_play "$audiofile"
    fi
    return $returncode
}

jv_bt_install () {
    jv_install pulseaudio bluez pulseaudio-module-bluetooth
}

jv_bt_uninstall () {
    jv_remove pulseaudio bluez pulseaudio-module-bluetooth
}

# call only if jv_use_bluetooth
jv_bt_init () {
    # make sure bluetooth HCI device is open and initialized
    sudo hciconfig hci0 up
    # make sure bluebooth device is not blocked
    sudo rfkill unblock bluetooth
    # power blutooth controller
    echo -e "power on\nquit\n" | bluetoothctl >/dev/null
    # pulseaudio needs to run for connecting bluetooth devices
    pulseaudio --start
}

# scan for bluetooth devices in pairing mode
jv_bt_scan () {
    (
        echo -e "scan on\n"
        sleep 10
        echo -e "scan off\n"
        echo -e "devices\n"
        echo -e "quit\n"
    ) | bluetoothctl | grep ^Device | cut -c 8-
}

# $1 - mac address of bluetooth device
jv_bt_is_connected () {
    pactl info | grep "bluez_sink.${1//:/_}" >/dev/null
    #echo -e "info $1\nquit\n" | bluetoothctl | grep "Connected: yes" >/dev/null
}

# $1 - mac address of bluetooth device
jv_bt_is_paired () {
    echo -e "paired-devices\nquit\n" | bluetoothctl | grep "^Device $1" >/dev/null
}

# $1 - mac address of bluetooth device
jv_bt_connect () {
    jv_debug "Connecting to $1..."
    if jv_bt_is_connected $1; then
        echo "Already connected"
        jv_play "sounds/connected.wav"
        return 0
    fi
    echo -e "devices\nquit\n" | bluetoothctl | grep "^Device $1" >/dev/null
    if [ $? -ne 0 ]; then
        jv_error "ERROR: $1 is not available"
        return 1
    fi
    if ! jv_bt_is_paired $1; then
        # pair & trust
        printf "Pairing..."
        (
            echo -e "pair $1\n"
            sleep 2
            echo -e "quit\n"
        ) | bluetoothctl >/dev/null
        if jv_bt_is_paired $1; then
            echo -e "trust $1\nquit\n" | bluetoothctl >/dev/null
            jv_success "Paired"
        else
            jv_error "Failed"
            return 1
        fi
    fi
    # connect
    printf "Connecting..."
    echo -e "connect $1\n" | bluetoothctl >/dev/null 2>&1 # Failed to connect: org.bluez.Error.Failed if pulseaudio not running
    for i in $(seq 1 5); do
        sleep 1
        if echo -e "info $1\nquit\n" | bluetoothctl | grep "Connected: yes" >/dev/null; then
            local bt_sink="bluez_sink.${1//:/_}"
            for i in $(seq 1 5); do
                # need time to bluez sink to appear
                sleep 1
                # check sink exists
                if pactl list short sinks | grep "$bt_sink" >/dev/null; then
                    # set bluetooth speaker as active audio device
                    pacmd set-default-sink "$bt_sink"
                    jv_success "Connected"
                    jv_play "sounds/connected.wav"
                    return 0
                fi
            done
            jv_warning "Sink was not created"
            break
        fi
    done
    jv_error "Failed"
    return 1
}

# $1 - mac address of bluetooth device
jv_bt_disconnect () {
    printf "Disconnecting..."
    echo -e "disconnect $1\nquit\n" | bluetoothctl >/dev/null
    for i in $(seq 1 5); do
        sleep 1
        if ! jv_bt_is_connected $1; then
            # stop pulseaudio if running
            #pulseaudio --check && pulseaudio --kill
            jv_success "Disconnected"
            jv_play "sounds/connected.wav"
            return 0
        fi
    done
    jv_error "Failed"
    return 1
}

jv_bt_forget () {
    echo -e "paired-devices\nquit\n" | bluetoothctl | grep "$1" >/dev/null
    if [ $? -ne 0 ]; then # if not paired
        jv_error "ERROR: $1 is not paired"
        return 1
    fi
    printf "Removing..."
    (
        echo -e "untrust $1\n"
        sleep 1
        echo -e "remove $1\n"
        sleep 1
        echo -e "quit\n"
    ) | bluetoothctl >/dev/null
    if [ $? -eq 0 ]; then
        jv_success "Removed"
    else
        jv_error "Failed"
        return 1
    fi
}

jv_bt_menu () {
    $jv_use_bluetooth || jv_bt_wizard
    if [ $? -ne 0 ]; then
        jv_use_bluetooth=false
        return
    fi
    jv_bt_init
    while true; do
        local options=()
        if [ -n "$jv_bt_device_mac" ]; then
            if jv_bt_is_connected "$jv_bt_device_mac"; then
                local bt_status="Connected"
                options+=("Disconnect")
            else
                local bt_status="Disconnected"
                options+=("Reconnect")
            fi
            options+=("Forget device")
        fi
        options+=("Scan"
                  "Use bluetooth ($jv_use_bluetooth)"
                  "Uninstall bluetooth")
        case "$(dialog_menu "Bluetooth\nSpeaker: ${jv_bt_device_name:-None} ($bt_status)" options[@])" in
            Use*)           configure "jv_use_bluetooth"
                            $jv_use_bluetooth || break;;
            Scan)           dialog_msg "Put your bluetooth device in pairing mode then click Ok"
                            jv_debug "Scanning bluetooth devices..."
                            local bt_devices=()
                            while read bt_device; do
                                bt_devices+=("$bt_device")
                            done < <( jv_bt_scan )
                            #TODO check list not empty
                            jv_bt_device="$(dialog_select "Bluetooth devices" bt_devices[@] false)"
                            if [ "$jv_bt_device" != "false" ]; then
                                jv_bt_device_mac="${jv_bt_device%% *}"
                                jv_bt_device_name="${jv_bt_device#* }"
                                jv_bt_connect "$jv_bt_device_mac" \
                                    || dialog_msg "Connection failed\nMake sure your device is in pairing mode"
                            fi
                            ;;
            Reconnect)      jv_bt_connect "$jv_bt_device_mac" \
                                || dialog_msg "Connection failed\nMake sure your device is in pairing mode"
                            ;;
            Disconnect)     jv_bt_disconnect "$jv_bt_device_mac";;
            Forget*)        jv_bt_disconnect "$jv_bt_device_mac"
                            jv_bt_forget "$jv_bt_device_mac"
                            jv_bt_device_mac=""
                            jv_bt_device_name=""
                            ;;
            Uninstall)      jv_bt_uninstall;;
            *)              break;;
        esac
    done
}

jv_bt_wizard () {
    configure "jv_use_bluetooth"
    $jv_use_bluetooth || return 1
    if ! jv_is_installed "pulseaudio-module-bluetooth"; then
        if dialog_yesno "pulseaudio-module-bluetooth doesn't seem to be installed. Install it?" >/dev/null; then
            jv_bt_install || return 1
        else
            return 1
        fi
    fi
}
