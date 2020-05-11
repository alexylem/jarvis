#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"
source bin/activate
sudo pip uninstall pvporcupine
deactivate

rm pyvenv.cfg
rm -rf bin include lib share
cd "$jv_dir"

jv_remove portaudio19-dev
