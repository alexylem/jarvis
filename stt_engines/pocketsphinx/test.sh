#!/bin/bash
dic="jarvis-dictionary.dic"
lm="jarvis-languagemodel.lm"
log="/dev/null"
hmm="fr_FR"
audiofile="`pwd`/test.wav"
echo "Recording... (press Ctrl+C to stop)"
AUDIODEV=hw:1,0 AUDIODRIVER=alsa rec -V1 -q -r 16000 -c 1 -b 16 -e signed-integer --endian little $audiofile
echo "Transcribing..."
result="`D_LIBRARY_PATH=/usr/local/lib PKG_CONFIG_PATH=/usr/local/lib/pkgconfig pocketsphinx_continuous -hmm $hmm -lm $lm -dict $dic -logfn $log -infile $audiofile`"
echo "result=$result"
