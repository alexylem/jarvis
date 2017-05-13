#!/usr/bin/env roundup

describe "Jarvis API"

it_starts_in_background() {
    jarvis -q || true # in case jarvis already running
    jarvis -b | grep "Jarvis has been launched in background"
}

it_checks_already_running() {
    sleep 0.5
    jarvis -b 2>&1 | grep "Jarvis is already running"
}

it_says_hello () {
    test "$(curl -s "localhost:8080?say=bonjour&mute=true")" = '[{"answer": "bonjour"}]'
}

it_says_hello_verbose () {
    test "$(curl -s "localhost:8080?say=bonjour&mute=true&verbose=True")" = '[{"debug": "DEBUG: start_speaking hook \"bonjour\""}, {"answer": "bonjour"}, {"debug": "DEBUG: stop_speaking hook"}]'
}

it_says_hello_verbose_false () {
    test "$(curl -s "localhost:8080?say=bonjour&mute=true&verbose=False")" = '[{"answer": "bonjour"}]'
}

it_gets_killed() {
   jarvis -q | grep  "Jarvis has been terminated"
}

it_but_not_twice () {
    sleep 0.5
    jarvis -q | grep "Jarvis is not running"
}
