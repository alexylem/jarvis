#!/bin/#!/usr/bin/env bash

_porcupine_install () {
  set -e
  jv_install portaudio19-dev python3 python3-pip python3-dev virtualenv
  cd "$(dirname "${BASH_SOURCE[0]}")"
  virtualenv -p python3 .
  source bin/activate
  pip3 install pvporcupine
  deactivate
  cd "$jv_dir"
}

# Check if porcupine is installed
[[ (-d "$(dirname "${BASH_SOURCE[0]}")/bin" ) && \
( -f "$(dirname "${BASH_SOURCE[0]}")/bin/pvporcupine_mic" ) ]] || {
  dialog_yesno "Porcupine doesn't seem to be installed.\nDo you want to install it?" true >/dev/null && {
      _porcupine_install
      dialog_msg "Porcupine installed sucessfully"
  }
}

_porcupine_STT () {
  cd "$(dirname "${BASH_SOURCE[0]}")"
  source bin/activate
  local quiet=""
  if ! $verbose; then
    quiet="2>/dev/null"
  fi
  eval "python main.py \"$trigger\" $quiet"
  retcode=$?
  deactivate
  cd "$jv_dir"

  # Return codes:
  # 0  -   Porcupine exited without an error and without detecting the keyword
  # 1  -   An error occurred
  # 11 -   The hotword was detected
  case $retcode in
    0)
      $verbose && jv_debug "WARNING: Porcupine hotword detection exited without the hotword being recognized"
      return 1
      ;;
    11)
      echo $trigger_sanitized > $forder
      ;;
    *)
      jv_error "ERROR: Porcupine hotword detection failed"
      jv_exit 1
  esac
  return 0
}

porcupine_STT () {
  if $bypass; then
    jv_error "ERROR: Porcupine must not be used as the command speech-to-text-engine"
    jv_exit 1
  fi

  _porcupine_STT
  return $?
}
