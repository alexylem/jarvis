#!/usr/bin/env roundup

describe "Jarvis JSON"

it_says_hello() {
    test "$(jarvis -mjs "bonjour")" = '[{"answer":"bonjour"}]'
}

it_executes_order() {
    test "$(jarvis -mjx "test")" = '[{"answer":"Ca fonctionne!"}]'
}

it_handles_nested_commands() {
    test "$(jarvis -mjx "ca va?" | jq -cM 'map(select(.answer))')" = '[{"answer":"Très bien et toi ça va?"}]'
}

it_handles_nested_answers() {
    test "$(jarvis -mjx "oui" | jq -cM 'map(select(.answer))')" = "[{\"answer\":\"ravi de l'entendre\"}]"
}
