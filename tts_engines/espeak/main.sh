#!/bin/bash
espeak_TTS () { # TTS () {} Speaks text $1
/usr/bin/espeak -v fr "$1" 2>/dev/null;
}
