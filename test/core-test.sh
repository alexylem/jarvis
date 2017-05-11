#!/usr/bin/env roundup

describe "Jarvis Core"

it_shows_help() {
    jarvis -h | grep Usage
}

it_checks_root () {
    test "$(sudo jarvis -w 2>&1)" = "ERROR: Jarvis must not be used as root"
}

it_says_hello() {
    test "$(jarvis -mws "bonjour")" = "Jarvis: bonjour"
}

it_executes_order() {
    test "$(jarvis -mwx "test")" = "Jarvis: Ca fonctionne!"
}

it_executes_unwknown_order() {
    test "$(jarvis -mwx "unknown")" = "Jarvis: Je ne comprends pas: unknown"
}

it_handles_order_captures() {
    test "$(jarvis -mwx "repete ceci et cela")" = "Jarvis: ceci cela"
}

it_handles_nested_commands() {
    test "$(jarvis -kmwx "ca va?" <<< "oui" | tail -n 1)" = "Alex: Jarvis: ravi de l'entendre"
}

it_handles_alternatives() {
    test "$(jarvis -mwx "termine")" = "Jarvis: Ok"
}

it_ignores_nested_alternatives() {
    test "$(jarvis -mwx "pas du tout")" = "Jarvis: Je ne comprends pas: pas du tout"
}

it_handles_nested_alternatives() {
    test "$(jarvis -kmwx "ca va?" <<< "pas du tout" | tail -n 1)" = "Alex: Jarvis: j'en suis navré"
}

it_runs_keyboard_mode () {
    jarvis -mk <<< "au revoir"
}

#it_starts_in_background() {
#    test "$(jarvis -b | head -n 1)" = "Jarvis has been launched in background"
#}

#it_gets_killed() {
#    sleep 1
#    test "$(jarvis -q)" = "Jarvis has been terminated"
#}

#it_but_not_twice() {
#    test "$(jarvis -q)" = "Jarvis is not running"
#}
