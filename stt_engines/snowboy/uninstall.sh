#!/bin/bash
if [ "$platform" = "linux" ]; then
    jv_remove python-pyaudio python3-pyaudio libatlas-base-dev
elif [[ "$platform" == "osx" ]]; then
    jv_remove portaudio
else
    exit 1
fi
jv_remove bzip2
sudo pip uninstall pyaudio
rm -rf resources
rm *snowboy*
