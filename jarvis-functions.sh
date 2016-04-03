##################
# Main Functions #
##################

# How to install sox?
# MacOSX: http://sourceforge.net/projects/sox/files/sox/14.4.2/
# Linux: "sudo apt-get install sox"

source stt_engines/$trigger_stt/main.sh
source stt_engines/$command_stt/main.sh
source tts_engines/$tts_engine/main.sh

PLAY () { # PLAY () {} Play audio file $1
    [ $play_hw != false ] && local play_export="AUDIODEV=$play_hw AUDIODRIVER=alsa" || local play_export=''
    eval "$play_export play -V1 -q $1";
}
LISTEN () { # LISTEN () {} Listens microhpone and record to audio file $1 when sound is detected until silence
    $verbose && local quiet='' || local quiet='-q'
    [ $rec_hw != false ] && local rec_export="AUDIODEV=$rec_hw AUDIODRIVER=alsa" || local rec_export=''
    eval "$rec_export rec -V1 $quiet -r 16000 -c 1 -b 16 -e signed-integer --endian little $1 silence 1 $min_noise_duration_to_start $min_noise_perc_to_start 1 $min_silence_duration_to_stop $min_silence_level_to_stop trim 0 $max_noise_duration_to_kill"
}
STT () { # STT () {} Transcribes audio file $1 and writes corresponding text in $forder
    $bypass && local stt_function=$command_stt'_STT' || local stt_function=$trigger_stt'_STT'
    $stt_function "$1"
}
TTS () { # TTS () {} Speaks text $1
    $tts_engine'_TTS' "$1"
}
