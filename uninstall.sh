#!/usr/bin/env bash
declare -f dialog_msg >/dev/null || {
    echo "To uninstall, please run jarvis -r"
    exit 1
}

jv_yesno "Are you sure you want to uninstall Jarvis and all its dependancies?" || exit 1

shopt -s nullglob

jv_warning "Uninstalling plugins"
cd plugins_installed
for plugin in *; do
    echo "uninstalling $plugin..."
    store_plugin_uninstall $plugin
done
cd ../

jv_warning "Uninstalling TTS engines"
cd tts_engines
for tts_engine in *; do
    echo "uninstalling $tts_engine..."
    cd $tts_engine
    uninstall.sh
    cd ../
done
cd ../

jv_warning "Uninstalling STT engines"
cd stt_engines
for stt_engine in *; do
    echo "uninstalling $stt_engine..."
    cd $stt_engine
    uninstall.sh
    cd ../
done
cd ../

jv_warning "Uninstalling jarvis core dependencies"
jv_remove jq sox libsox-fmt-mp3

jv_warning "Removing jarvis folder"
if jv_yesno "Do you want to backup your jarvis config?"; then
    cp -R config ~/jarvis_backup/
    echo "config/ has been copied into ~/jarvis_backup"
fi
cd ../
rm -rf jarvis

jv_success "Jarvis has been uninstalled successfuly"
jv_debug "If you are not happy with Jarvis, please let me know the reasons at alexandre.mely@gmail.com"

exit 0
