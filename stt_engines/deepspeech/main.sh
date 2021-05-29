#!/bin/bash

stt_deepspeech_install () {
  set -e # Don't attempt to continue if an error occurs
  jv_install python3 python3-pip virtualenv
  cd "$(dirname "${BASH_SOURCE[0]}")"
  virtualenv -p python3 .
  source bin/activate
  pip3 install deepspeech
  deactivate
  wget "https://github.com/mozilla/DeepSpeech/releases/download/v${deepspeech_version}/$deepspeech_model"
  wget "https://github.com/mozilla/DeepSpeech/releases/download/v${deepspeech_version}/$deepspeech_scorer"
  cd "$jv_dir"
}

stt_deepspeech_update () {
  set -e
  cd "$(dirname "${BASH_SOURCE[0]}")"

  source bin/activate
  pip3 install -U deepspeech # Upgrade deepspeech package
  deactivate

  rm *.pbmm *.tflite *.scorer # Remove old models and scorer
  wget "https://github.com/mozilla/DeepSpeech/releases/download/v${deepspeech_version}/$deepspeech_model"
  wget "https://github.com/mozilla/DeepSpeech/releases/download/v${deepspeech_version}/$deepspeech_scorer"

  cd "$jv_dir"
}

# Check if DeepSpeech is installed and install it if necessary
[[ ( -f "$(dirname "${BASH_SOURCE[0]}")/bin/deepspeech" ) && \
( -f "$(dirname "${BASH_SOURCE[0]}")/bin/activate" ) ]] || {
  dialog_yesno "DeepSpeech doesn't seem to be installed.\nDo you want to install it?" true >/dev/null && {
      stt_deepspeech_install
      dialog_msg "DeepSpeech installed sucessfully"
  }
}

# Check if the current models exist and download them if they don't
[[ ( -f "$(dirname "${BASH_SOURCE[0]}")/$deepspeech_model" ) && \
( -f "$(dirname "${BASH_SOURCE[0]}")/$deepspeech_scorer" ) ]] || {
  dialog_yesno "The current DeepSpeech models appear to be missing. Do you want to download them?" true >/dev/null && {
      stt_deepspeech_update
      dialog_msg "DeepSpeech updated sucessfully"
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
