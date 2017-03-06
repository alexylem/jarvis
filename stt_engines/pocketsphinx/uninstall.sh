#!/usr/bin/env bash
if [[ "$platform" == "linux" ]]; then
    jv_remove bison libasound2-dev python-dev swig    
elif [[ "$platform" == "osx" ]]; then
    jv_remove wget swig
else
    exit 1
fi
cd sphinxbase-5prealpha
make uninstall
cd ../
cd pocketsphinx-5prealpha
make uninstall
cd ../
