#!/bin/bash
echo "platform=$platform"
echo "1/4 Preparation of dependencies"
if [[ "$platform" == "linux" ]]; then
    echo -e "\tUpdating..."
    sudo apt-get -qq update || exit 1
    echo -e "\tUpgrading..."
    sudo apt-get -qq upgrade -y || exit 1
    echo -e "\tDownloading & Installing Dependencies..."
    sudo apt-get install -y bison libasound2-dev python-dev swig >/dev/null || exit 1
    
elif [[ "$platform" == "osx" ]]; then
    echo -e "\tDownloading & Installing Dependencies..."
    brew install wget swig || exit 1
else
    echo "Execute ../jarvis.sh -i"
    exit 1
fi
echo "2/4 Installation of SphinxBase"
echo -e "\tDownloading..."
wget -q -O sphinxbase-5prealpha.tar.gz https://sourceforge.net/projects/cmusphinx/files/sphinxbase/5prealpha/sphinxbase-5prealpha.tar.gz/download || exit 1
echo -e "\tUnpacking..."
tar -xzf sphinxbase-5prealpha.tar.gz || exit 1
cd sphinxbase-5prealpha
echo -e "\tConfiguring..."
./configure --enable-fixed >/dev/null || exit 1
echo -e "\tCompiling..."
make >/dev/null || exit 1
echo -e "\tInstalling..."
sudo make install >/dev/null || exit 1
cd ../
echo "3/4 Installation of PocketSphinx"
echo -e "\tDownloading..."
wget -q -O pocketsphinx-5prealpha.tar.gz wget https://sourceforge.net/projects/cmusphinx/files/pocketsphinx/5prealpha/pocketsphinx-5prealpha.tar.gz/download
echo -e "\tUnpacking..."
tar -xzf pocketsphinx-5prealpha.tar.gz || exit 1
cd pocketsphinx-5prealpha
echo -e "\tConfiguring..."
./configure >/dev/null || exit 1
echo -e "\tCompiling..."
make >/dev/null || exit 1
echo -e "\tInstalling..."
sudo make install >/dev/null || exit 1
echo "4/4 Cleanup"
echo -e "\tCleaning files..."
rm sphinxbase-5prealpha.tar.gz || exit 1
rm pocketsphinx-5prealpha.tar.gz || exit 1
echo "[Installation Completed]"
