#!/usr/bin/env roundup

describe "Jarvis API"

it_starts_in_background() {
    ./jarvis.sh -q || true
    ./jarvis.sh -b | grep "Jarvis has been launched in background"
}

it_checks_already_running() {
    sleep 0.5
    ./jarvis.sh -b 2>&1 | grep "Jarvis is already running"
}

it_says_hello () {
    test "$(curl -s "localhost:8080?say=bonjour&mute=true")" = '[{"answer": "bonjour"}]'
}

it_says_hello_verbose () {
    test "$(curl -s "localhost:8080?say=bonjour&mute=true&verbose=true")" = '[{"debug": "DEBUG: start_speaking hook \"bonjour\""}, {"answer": "bonjour"}, {"debug": "DEBUG: stop_speaking hook"}]'
}

it_says_hello_verbose_false () {
    test "$(curl -s "localhost:8080?say=bonjour&mute=true&verbose=false")" = '[{"answer": "bonjour"}]'
}

it_gets_killed() {
   kill $(cat /tmp/jarvis.lock) # -q breaks roundup
   sleep 0.5
   ./jarvis.sh -q | grep "Jarvis is not running"
}
