#!/bin/bash

# Jarvis main menu
jv_menu_main () {
    while true; do
        options=('Start Jarvis'
                 'Settings'
                 'Commands (what JARVIS can understand and execute)'
                 'Events (what JARVIS monitors and notifies you about)'
                 'Plugins (commands from community)'
                 'Search for updates'
                 'Help / Report a problem'
                 'About')
        case "`dialog_menu \" Jarvis - v$jv_version\n$headline\" options[@]`" in
            Start*)
                while true; do
                    options=('Start normally' 'Troubleshooting mode' 'Keyboard mode' 'Start as a service')
                    case "`dialog_menu 'Start Jarvis' options[@]`" in
                        "Start normally")
                            break 2;;
                        "Troubleshooting mode")
                            verbose=true
                            break 2;;
                        "Keyboard mode")
                            keyboard=true
                            quiet=true
                            break 2;;
                        "Start as a service")
                            jv_start_in_background
                            exit;;
                        *) break;;
                    esac
                done;;
            Settings)
                while true; do
                    options=('Step-by-step wizard'
                             'General'
                             'Phrases'
                             'Audio'
                             'Voice recognition'
                             'Speech synthesis'
                             'Hooks')
                    case "`dialog_menu 'Configuration' options[@]`" in
                        "Step-by-step wizard")
                            wizard;;
                        "General")
                            while true; do
                                options=("Username ($username)"
                                         "Trigger mode ($trigger_mode)"
                                         "Magic word ($trigger)"
                                         "Show possible commands ($show_commands)"
                                         "Multi-command separator ($separator)"
                                         "Conversation mode ($conversation_mode)"
                                         "Language ($language)"
                                         "Check Updates on Startup ($check_updates)"
                                         "Repository Branch ($jv_branch)"
                                         "Usage Statistics ($send_usage_stats)")
                                case "`dialog_menu 'Configuration > General' options[@]`" in
                                    Username*) configure "username";;
                                    Trigger*) configure "trigger_mode";;
                                    Magic*word*) configure "trigger";;
                                    Show*commands*) configure "show_commands";;
                                    Multi-command*separator*) configure "separator";;
                                    Conversation*) configure "conversation_mode";;
                                    Language*) configure "language";;
                                    Check*Updates*) configure "check_updates";;
                                    Repository*Branch*) configure "jv_branch";;
                                    Usage*Statistics*) configure "send_usage_stats";;
                                    *) break;;
                                esac
                            done;;
                        "Phrases")
                            while true; do
                                options=("Startup greetings ($phrase_welcome)" "Trigger reply ($phrase_triggered)" "Unknown order ($phrase_misunderstood)" "Command failed ($phrase_failed)")
                                case "`dialog_menu 'Configuration > Phrases' options[@]`" in
                                    Startup*greetings*) configure "phrase_welcome";;
                                    Trigger*reply*)     configure "phrase_triggered";;
                                    Unknown*order*)     configure "phrase_misunderstood";;
                                    Command*failed*)    configure "phrase_failed";;
                                    *) break;;
                                esac
                            done;;
                        "Audio")
                            while true; do
                                options=("Speaker ($play_hw)"
                                         "Mic ($rec_hw)"
                                         "Bluetooth (experimental)"
                                         "Recorder ($recorder)"
                                         "Auto-adjust levels"
                                         "Volume"
                                         "Tempo ($tempo)"
                                         "Sensitivity"
                                         "Gain ($gain)"
                                         "Timeout ($jv_timeout)"
                                         "Min noise duration to start ($min_noise_duration_to_start)"
                                         "Min noise perc to start ($min_noise_perc_to_start)"
                                         "Min silence duration to stop ($min_silence_duration_to_stop)"
                                         "Min silence level to stop ($min_silence_level_to_stop)")
                                case "`dialog_menu 'Configuration > Audio' options[@]`" in
                                    Speaker*)   configure "play_hw";;
                                    Mic*)       configure "rec_hw";;
                                    Recorder*)  configure "recorder";;
                                    Bluetooth*) jv_bt_menu;;
                                    Auto*)      jv_auto_levels;;
                                    Volume)     if [ "$platform" == "osx" ]; then
                                                    osascript <<EOM
                                                        tell application "System Preferences"
                                                            activate
                                                            set current pane to pane "com.apple.preference.sound"
                                                            reveal (first anchor of current pane whose name is "output")
                                                        end tell
EOM
                                                else
                                                    alsamixer -c ${play_hw:3:1} -V playback || read -p "ERROR: check above"
                                                fi;;
                                    Tempo*)     configure "tempo";;
                                    Sensitivity)
                                                if [ "$platform" == "osx" ]; then
                                                    osascript <<EOM
                                                        tell application "System Preferences"
                                                            activate
                                                            set current pane to pane "com.apple.preference.sound"
                                                            reveal (first anchor of current pane whose name is "input")
                                                        end tell
EOM
                                                else
                                                    alsamixer -c ${rec_hw:3:1} -V capture || read -p "ERROR: check above"
                                                fi;;
                                    Gain*)            configure "gain";;
                                    Timeout*)         configure "jv_timeout";;
                                    *duration*start*) configure "min_noise_duration_to_start";;
                                    *perc*start*)     configure "min_noise_perc_to_start";;
                                    *duration*stop*)  configure "min_silence_duration_to_stop";;
                                    *level*stop*)     configure "min_silence_level_to_stop";;
                                    *) break;;
                                esac
                            done;;
                        "Voice recognition")
                            while true; do
                                options=("Recognition of magic word ($trigger_stt)"
                                         "Recognition of commands ($command_stt)"
                                         "Snowboy settings"
                                         "Google settings"
                                         "Bing settings"
                                         "Wit settings"
                                         "PocketSphinx setting")
                                case "`dialog_menu 'Settings > Voice recognition' options[@]`" in
                                    Recognition*magic*word*)    configure "trigger_stt";;
                                    Recognition*command*)       configure "command_stt";;
                                    Snowboy*)
                                        while true; do
                                            options=("Show trained hotwords/commands"
                                                     "Token ($snowboy_token)"
                                                     "Train a hotword/command"
                                                     "Sensitivity ($snowboy_sensitivity)"
                                                     "Check ticks ($snowboy_checkticks)")
                                            case "`dialog_menu 'Settings > Voice recognition > Snowboy' options[@]`" in
                                                Check*)         configure "snowboy_checkticks";;
                                                Show*)          source stt_engines/snowboy/main.sh
                                                                IFS=','; dialog_msg "Models stored in stt_engines/snowboy/resources/:\n${snowboy_models[*]}";;
                                                Sensitivity*)   configure "snowboy_sensitivity";;
                                                Token*)         configure "snowboy_token";;
                                                Train*)         source stt_engines/snowboy/main.sh
                                                                stt_sb_train "$(dialog_input "Hotword / Quick Command to (re-)train" "$trigger")" true
                                                                ;;
                                                *) break;;
                                            esac
                                        done;;
                                    Google*)
                                            while true; do
                                                options=("Google key ($google_speech_api_key)")
                                                case "`dialog_menu 'Settings > Voice recognition > Google' options[@]`" in
                                                    Google*key*)  configure "google_speech_api_key";;
                                                    *) break;;
                                                esac
                                            done;;
                                    Bing*)
                                            while true; do
                                                options=("Bing key ($bing_speech_api_key)")
                                                case "`dialog_menu 'Settings > Voice recognition > Bing' options[@]`" in
                                                    Bing*key*)  configure "bing_speech_api_key";;
                                                    *) break;;
                                                esac
                                            done;;
                                    Wit*)
                                        while true; do
                                            options=("Wit key ($wit_server_access_token)")
                                            case "`dialog_menu 'Settings > Voice recognition > Wit' options[@]`" in
                                                Wit*)   configure "wit_server_access_token";;
                                                *) break;;
                                            esac
                                        done;;
                                    PocketSphinx*)
                                        while true; do
                                            options=("PocketSphinx dictionary ($dictionary)"
                                                     "PocketSphinx language model ($language_model)"
                                                     "PocketSphinx logs ($pocketsphinxlog)")
                                            case "`dialog_menu 'Settings > Voice recognition > PocketSphinx' options[@]`" in
                                                PocketSphinx*dictionary*)   configure "dictionary";;
                                                PocketSphinx*model*)        configure "language_model";;
                                                PocketSphinx*logs*)         configure "pocketsphinxlog";;
                                                *) break;;
                                            esac
                                        done;;
                                    *) break;;
                                esac
                            done;;
                        "Speech synthesis")
                            while true; do
                                options=("Speech engine ($tts_engine)" "OSX voice ($osx_say_voice)") #"Voxygen voice ($voxygen_voice)" 
                                case "`dialog_menu 'Configuration > Speech synthesis' options[@]`" in
                                    Speech*engine*) configure "tts_engine";;
                                    #Voxygen*voice*) configure "voxygen_voice";;
                                    OSX*voice*)     configure "osx_say_voice";;
                                    *) break;;
                                esac
                            done;;
                        "Hooks")
                            while true; do
                                options=("Program startup"
                                         "Start listening"
                                         "Stop listening"
                                         "Listening timeout"
                                         "Entering command mode"
                                         "Start speaking"
                                         "Stop speaking"
                                         "Exiting command mode"
                                         "Program exit")
                                case "`dialog_menu 'Configuration > Hooks' options[@]`" in
                                    Program*startup*)   configure "program_startup";;
                                    Program*exit*)      configure "program_exit";;
                                    Entering*)          configure "entering_cmd";;
                                    Exiting*)           configure "exiting_cmd";;
                                    Listening*timeout)  configure "listening_timeout";;
                                    Start*listening*)   configure "start_listening";;
                                    Stop*listening*)    configure "stop_listening";;
                                    Start*speaking*)    configure "start_speaking";;
                                    Stop*speaking*)     configure "stop_speaking";;
                                    *) break;;
                                esac
                            done;;
                        *) break;;
                    esac
                done
                configure "save";;
            Commands*)
                editor jarvis-commands
                #update_commands
                ;;
            Events*)
                dialog_msg <<EOM
    WARNING: JARVIS currently uses Crontab to schedule monitoring & notifications
    This will erase crontab entries you may already have, check with:
        crontab -l
    If you already have crontab rules defined, add them to JARVIS events:
        crontab -l >> jarvis-events
    Press [Ok] to start editing Event Rules
EOM
                editor jarvis-events &&
                crontab jarvis-events -i;;
            Plugins*)
                jv_menu_store
                ;;
            Help*)
                dialog_msg <<EOM
    A question?
    http://openjarvis.com/content/support

    A problem or enhancement request?
    Create a ticket on GitHub
    https://github.com/alexylem/jarvis/issues/new

    Just want to discuss?
    http://openjarvis.com/content/disqus
EOM
                ;;
            "About") dialog_msg <<EOM
    JARVIS
    By Alexandre Mély

    http://openjarvis.com
    alexandre.mely@gmail.com
    (I don't give support via email, please check Help)

    You like Jarvis? consider making a 1€ donation:
    http://openjarvis.com/content/credits

    JARVIS is freely distributable under the terms of the MIT license.
EOM
                ;;
            "Search for updates")
                jv_check_updates
                jv_plugins_check_updates
                touch config/last_update_check
                if $jv_jarvis_updated; then
                    echo "Please restart Jarvis"
                    exit
                fi
                ;;
            *) exit;;
        esac
    done
}

# Internal: display dialog of $plugins
# $1 - dialog title
menu_store_browse () { # $1 (optional) sorting, $2 (optionnal) space separated search terms    
    while true; do        
        # Select plugin
        local plugin_title="`dialog_menu \"$1\" plugins[@]`"
        
        [ -z "$plugin_title" ] && break
        if [ -z "$plugin_title" ] || [ "$plugin_title" == "false" ]; then
            break
        fi
        
        local plugin_url=$(store_get_field "$plugin_title" 'repo') #https://github.com/alexylem/jarvis
        
        while true; do
            # Display plugin details
            store_display_readme "$plugin_url"
            
            # Plugin menu
            local options=("Info"
                     "Install")
            case "`dialog_menu \"$plugin_title\" options[@]`" in
                Info)    continue;;
                Install) 
                         store_install_plugin "$plugin_url"
                         break 2;;
                *)       break;;
            esac
        done
    done
}

jv_menu_store () {
    store_init
    local categories=($(store_get_categories))
    
    while true; do
        local plugins=()
        shopt -s nullglob
        nb_installed=(plugins_installed/*/)
        shopt -u nullglob
        
        options=("Installed (${#nb_installed[@]})"
                 "Matching Order"
                 "Search"
                 "Browse ($(store_get_nb_plugins))" # total
                 "Recommended Plugins"
                 "New Plugins" #TODO X new since last visit
                 "Top Plugins" #TODO top X
                 "Update (retrieve new list of plugins)"
                 "Install from URL" #TODO also as jarvis option argument
                 "Create a Plugin")
        case "`dialog_menu 'Plugins' options[@]`" in
            Installed*) if [ "${#nb_installed[@]}" -gt 0 ]; then
                            #cd plugins_installed/
                            while true; do
                                options=()
                                for plugin in $(ls plugins_installed); do
                                    options+=("$plugin$(jv_plugin_is_enabled "$plugin" || echo " (disabled)")")
                                done
                                local plugin="$(dialog_menu "Installed" options[@])"
                                plugin="${plugin% *}" # remove (disabled)
                                if [ -n "$plugin" ] && [ "$plugin" != "false" ]; then
                                    cd "plugins_installed/$plugin"
                                    local plugin_git_url="$(git config --get remote.origin.url)"
                                    cd ../../
                                    local plugin_url="${plugin_git_url%.*}"
                                    while true; do
                                        jv_plugin_is_enabled $plugin && local enable_disable="Disable" || local enable_disable="Enable"
                                        options=("Info"
                                                 "Configure"
                                                 "$enable_disable"
                                                 "Update"
                                                 "Rate"
                                                 "Report an issue"
                                                 "Uninstall")
                                        case "`dialog_menu \"$plugin\" options[@]`" in
                                            Info)
                                                store_display_readme "$plugin_url"
                                                ;;
                                            Configure)
                                                editor "plugins_installed/$plugin/config.sh"
                                                ;;
                                            Disable)
                                                jv_plugin_disable "$plugin"
                                                break # back to list of plugins
                                                ;;
                                            Enable)
                                                jv_plugin_enable "$plugin"
                                                break # back to list of plugins
                                                ;;
                                            Update)
                                                jv_check_updates "plugins_installed/$plugin" false
                                                ;;
                                            Rate)
                                                dialog_msg "$(store_get_field_by_repo "$plugin_url" "url")#comment-form"
                                                ;;
                                            Report*)
                                                dialog_msg "$plugin_url/issues/new"
                                                ;;
                                            Uninstall)
                                                if dialog_yesno "Are you sure?" true >/dev/null; then
                                                    store_plugin_uninstall "$plugin"
                                                    dialog_msg "Uninstallation Complete"
                                                    break # back to list of plugins
                                                fi
                                                ;;
                                            *)  break;;
                                        esac
                                    done
                                else
                                    break
                                fi
                            done
                            #cd ../
                        fi
                        ;;
            Matching*)  dialog_msg <<EOM
This is to edit the order in which the plugin commands are evaluated
Put at the bottom plugins with generic patterns, such as Jeedom or API
EOM
                        editor plugins_order.txt
                        jv_plugins_order_rebuild # in case of user mistake
                        ;;
            Search*)    local search_terms="$(dialog_input "Search in Plugins (keywords seperate with space)" "$search_terms")"
                        while read plugin; do
                            plugins+=("$plugin")
                        done <<< "$(jv_store_search_plugins "$search_terms")"
                        menu_store_browse "Search results"
                        ;;
            Browse*)    category="$(dialog_menu 'Categories' categories[@])"
                        [ "$category" = false ] && continue # user pressed cancel
                        while read plugin; do
                            plugins+=("$plugin")
                        done <<< "$(jv_store_list_plugins_category "$category")"
                        menu_store_browse "$category"
                        ;;
            Recommended*)
                        while read plugin; do
                            plugins+=("$plugin")
                        done <<< "$(jv_store_list_plugins_recommended)"
                        menu_store_browse "Recommended Plugins"
                        ;;
            New*)       while read plugin; do
                            plugins+=("$plugin")
                        done <<< "$(jv_store_list_plugins_top "date" 15)"
                        menu_store_browse "New Plugins"
                        ;;
            Top*)       while read plugin; do
                            plugins+=("$plugin")
                        done <<< "$(jv_store_list_plugins_top "rating" 15)"
                        menu_store_browse "Popular Plugins"
                        ;;
            Update*)    jv_store_update;;
            Install*)   local plugin_url="$(dialog_input "Repo URL, ex: https://github.com/alexylem/jarvis-time")"
                        [ -z "$plugin_url" ] && continue
                        store_install_plugin "$plugin_url"
                        ;;
            Create*)    jv_store_create_plugin
                        ;;
            *) break;;
        esac
    done
}
