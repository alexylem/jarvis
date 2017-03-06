#!/bin/bash
voxygen_TTS () { # Speaks text $1
    local audio_file="$jv_cache_folder/$(jv_sanitize "$1" _).mp3"
    if [ ! -f "$audio_file" ]; then
        $verbose && printf "$_gray" # output in verbose mode will be displayed in gray
        wget $($verbose || echo -q) -O "$audio_file" "http://www.voxygen.fr/sites/all/modules/voxygen_voices/assets/proxy/index.php?method=redirect&text=$1&voice=$voxygen_voice&ts=1480362849466"
        $verbose && printf "$_reset"
    fi
    mpg123 -q "$audio_file" 2>/dev/null #sometimes segmentation fault, don't know why but it works... still with 2>/dev/null error appears
    return 0 # avoid above error code
}
