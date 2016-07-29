#!/bin/bash
source main.sh

verbose=true
platform="osx"
language="en-US"
audiofile="test.wav"
bing_speech_api_key="$(cat ../../config/bing_speech_api_key)"

_bing_transcribe
