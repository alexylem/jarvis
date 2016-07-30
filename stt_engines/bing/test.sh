#!/bin/bash
source ../../utils/utils.sh
source main.sh

verbose=true
platform="osx"
language="en-US"
audiofile="test.wav"
bing_speech_api_key="$(cat ../../config/bing_speech_api_key)"
forder="/dev/stdout"

_bing_transcribe
