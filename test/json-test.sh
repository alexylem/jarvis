#!/usr/bin/env roundup

describe "Jarvis JSON"

it_says_hello() {
    test "$(./jarvis.sh -mjs "bonjour")" = '[{"Jarvis":"bonjour"}]'
}

it_executes_order() {
    test "$(./jarvis.sh -mjx "test")" = '[{"Jarvis":"Ca fonctionne!"}]'
}

it_handles_nested_commands() {
    test "$(./jarvis.sh -mjx "ca va?")" = '[{"Jarvis":"Très bien et toi ça va?"}]'
}

it_handles_nested_answers() {
    test "$(./jarvis.sh -mjx "oui")" = "[{\"Jarvis\":\"ravi de l'entendre\"}]"
}
