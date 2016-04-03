#!/bin/bash
pocketsphinx_STT () { # STT () {} Transcribes audio file $1 and writes corresponding text in $forder
LD_LIBRARY_PATH=/usr/local/lib PKG_CONFIG_PATH=/usr/local/lib/pkgconfig pocketsphinx_continuous -lm $language_model -dict $dictionary -logfn $pocketsphinxlog -infile $1 > $forder
}
