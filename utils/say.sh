#!/bin/bash
while true; do
    while read -r phrase; do
        $tts_engine'_TTS' "$phrase"
    done < $jv_say_queue
    sleep 1 # delay between piped phrases
done
