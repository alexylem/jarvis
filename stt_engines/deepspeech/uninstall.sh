#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

source bin/activate
sudo pip uninstall deepspeech
deactivate

rm deepspeech*
rm -rf bin include lib share

cd "$jv_dir"
