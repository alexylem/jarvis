#!/bin/bash

_deepspeech_transcribe () {
  cd "$(dirname "${BASH_SOURCE[0]}")"
  source ./bin/activate
  transcribed="$(deepspeech --model $deepspeech_model $([[ -n "$deepspeech_scorer" ]] \
    && echo "--scorer $deepspeech_scorer ")--audio $audiofile 2>/dev/null)"
  deactivate

  $verbose && jv_debug "DEBUG: $transcribed" 

  echo $transcribed > $forder
}

deepspeech_STT () { # STT () {} Listen & transcribes audio file then writes corresponding text in $forder
    LISTEN $audiofile || return $?
    _deepspeech_transcribe &
   jv_spinner $!
}
