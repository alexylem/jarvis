#!/bin/bash

stt_deepspeech_install () {
  set -e # Don't attempt to continue if an error occurs
  jv_install python3 python3-pip virtualenv
  cd "$(dirname "${BASH_SOURCE[0]}")"
  virtualenv -p python3 .
  source bin/activate
  pip3 install deepspeech
  deactivate
  wget https://github.com/mozilla/DeepSpeech/releases/download/v0.7.0/deepspeech-0.7.0-models.pbmm
  wget https://github.com/mozilla/DeepSpeech/releases/download/v0.7.0/deepspeech-0.7.0-models.scorer
  cd "$jv_dir"
}

# Check if the needed files exist and install DeepSpeech if they don't
[[ ( -f "$(dirname "${BASH_SOURCE[0]}")/deepspeech-0.7.0-models.pbmm" ) && \
( -f "$(dirname "${BASH_SOURCE[0]}")/deepspeech-0.7.0-models.pbmm" ) && \
( -d "$(dirname "${BASH_SOURCE[0]}")/bin" ) && \
( -f "$(dirname "${BASH_SOURCE[0]}")/bin/deepspeech" ) ]] || {
  dialog_yesno "DeepSpeech doesn't seem to be installed.\nDo you want to install it?" true >/dev/null && {
      stt_deepspeech_install
      dialog_msg "DeepSpeech installed sucessfully"
  }
}

_deepspeech_transcribe () {
  cd "$(dirname "${BASH_SOURCE[0]}")"
  source bin/activate
  transcribed="$(deepspeech --model $deepspeech_model $([[ -n "$deepspeech_scorer" ]] \
    && echo "--scorer $deepspeech_scorer ")--audio $audiofile 2>"deepspeech.log")"
  deactivate
  cd "$jv_dir"

  $verbose && jv_debug "DEBUG: $transcribed"

  echo $transcribed > $forder
}

deepspeech_STT () { # STT () {} Listen & transcribes audio file then writes corresponding text in $forder
    LISTEN $audiofile || return $?
    _deepspeech_transcribe &
   jv_spinner $!
}
