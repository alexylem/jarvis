#!/bin/bash
espeak_TTS () { # TTS () {} Speaks text $1
/usr/bin/espeak -v ${language:0:2} "$1" 2>/dev/null;
}
