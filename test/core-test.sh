#!/usr/bin/env roundup

describe "Jarvis Core"

it_shows_help() {
    ./jarvis.sh -h | grep Usage
}

it_checks_root () {
    test "$(sudo ./jarvis.sh -w)" = "ERROR: Jarvis must not be used as root"
}

it_says_hello() {
    test "$(./jarvis.sh -mws "bonjour")" = "Jarvis: bonjour"
}

it_executes_order() {
    test "$(./jarvis.sh -mwx "test")" = "Jarvis: Ca fonctionne!"
}

it_executes_unwknown_order() {
    test "$(./jarvis.sh -mwx "unknown")" = "Jarvis: Je ne comprends pas: unknown"
}

it_handles_order_captures() {
    test "$(./jarvis.sh -mwx "repete ceci et cela")" = "Jarvis: ceci cela"
}

it_handles_nested_commands() {
    test "$(./jarvis.sh -kmwx "ca va?" <<< "oui" | tail -n 1)" = "Alex: Jarvis: ravi de l'entendre"
}
