#!/usr/bin/env roundup
set +o posix

describe "Jarvis Utils"
source utils/utils.sh

it_escapes_json () {
    test "$(jv_print_json 'key' 'a"b%c')" = '{"key":"a\"b%c"}'
}

it_appends_json () {
    jv_print_json key value
    test "$(jv_print_json 'key' 'value')" = ',{"key":"value"}'
}

it_sanitizes () {
    test $(jv_sanitize 'aAé?-_ ' _) = 'aae-__'
}

it_yesno_question_yes () {
    jv_yesno "a question" <<< y
}

it_yesno_question_no () {
    test $(jv_yesno "a question" <<< n; echo $?) -eq 1
}
