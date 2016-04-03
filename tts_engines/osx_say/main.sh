#!/bin/bash
osx_say_TTS () { # TTS () {} Speaks text $1
voice=`/usr/bin/say -v ? | grep $language | awk '{print $1}'`
/usr/bin/say -v $voice $1;
}
