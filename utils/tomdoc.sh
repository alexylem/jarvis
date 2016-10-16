#!/bin/sh
#/ Usage: tomdoc.sh [options] [--] [<shell-script>...]
#/
#/     -h, --help               show help text
#/     --version                show version
#/     -t, --text               produce plain text (default format)
#/     -m, --markdown           produce markdown
#/     -a, --access <level>     filter by access level
#/
#/ Parse TomDoc'd shell scripts and generate pretty documentation from it.
#
# Written by Mathias Lafeldt <mathias.lafeldt@gmail.com>, later project was
# transfered to Tyler Akins <fidian@rumkin.com>.

set -e
test -n "$TOMDOCSH_DEBUG" && set -x

# Current version of tomdoc.sh.
TOMDOCSH_VERSION="0.1.7"

generate=generate_text
access=

while test "$#" -ne 0; do
    case "$1" in
    -h|--h|--he|--hel|--help)
        grep '^#/' <"$0" | cut -c4-
        exit 0
        ;;
    --version)
        printf "tomdoc.sh version %s\n" "$TOMDOCSH_VERSION"
        exit 0
        ;;
    -t|--t|--te|--tex|--text)
        generate=generate_text
        shift
        ;;
    -m|--m|--ma|--mar|--mark|--markd|--markdo|--markdow|--markdown)
        generate=generate_markdown
        shift
        ;;
    -a|--a|--ac|--acc|--acce|--acces|--access)
        test "$#" -ge 2 || {
            printf "error: %s requires an argument\n" "$1" >&2
            exit 1
        }
        access="$2"
        shift 2
        ;;
    --)
        shift
        break
        ;;
    -|[!-]*)
        break
        ;;
    -*)
        printf "error: invalid option '%s'\n" "$1" >&2
        exit 1
        ;;
    esac
done


# Regular expression matching whitespace.
SPACE_RE='[[:space:]]*'
# The inverse of the above, must match at least one character
NOT_SPACE_RE='[^[:space:]][^[:space:]]*'
# Regular expression matching shell function or variable name.
NAME_RE='[a-zA-Z_][a-zA-Z0-9_]*'

# Strip leading whitespace and '#' from TomDoc strings.
#
# Returns nothing.
uncomment() {
    sed -e "s/^$SPACE_RE# \{0,1\}//"
}

# Generate the documentation for a shell function or variable in plain text
# format and write it to stdout.
#
# $1 - Function or variable name
# $2 - TomDoc string
#
# Returns nothing.
generate_text() {
    cat <<EOF
--------------------------------------------------------------------------------
$1

$(printf "%s" "$2" | uncomment)

EOF
}

# Generate the documentation for a shell function or variable in markdown format
# and write it to stdout.
#
# $1 - Function or variable name
# $2 - TomDoc string
#
# Returns nothing.
generate_markdown() {
    local line last did_newline last_was_option

    printf "%s\n" '`'"$1"'`'
    printf "%s" " $1 " | tr -c - -
    printf "\n\n"

    last=""
    did_newline=false
    last_was_option=false

    printf "%s\n" "$2" | uncomment | sed -e "s/$SPACE_RE$//" | while IFS='' read -r line; do
        if printf "%s" "$line" | grep -q "^$SPACE_RE$NOT_SPACE_RE $SPACE_RE- "; then
            # This is for arguments
            if ! $did_newline; then
                printf "\n"
            fi

            if printf "%s" "$line" | grep -q "^$NOT_SPACE_RE"; then
                printf "%s" "* $line"
            else
                printf "    * "
                printf "%s" "$line" | sed "s/^$SPACE_RE//"
            fi

            last_was_option=true

            # shellcheck disable=SC2030

            did_newline=false
        else
            case "$line" in
                "")
                    # Check for end of paragraph / section
                    if ! $did_newline; then
                        printf "\n"
                    fi

                    printf "\n"
                    did_newline=true
                    last_was_option=false
                    ;;

                "  "*)
                    # Examples and option continuation
                    if $last_was_option; then
                        printf "%s" "$line" | sed "s/^ */ /"
                        did_newline=false
                    else
                        printf "  %s\n" "$line"
                        did_newline=true
                    fi
                    ;;

                "* "*)
                    # A list should not continue a previous paragraph.
                    printf "%s\n" "$line"
                    did_newline=true
                    ;;

                *)
                    # Paragraph text (does not start with a space)
                    case "$last" in
                        "")
                            # Start a new paragraph - no space at the beginning
                            printf "%s" "$line"
                            ;;

                        *)
                            # Continue this line - include space at the beginning
                            printf " %s" "$line"
                            ;;
                    esac

                    did_newline=false
                    last_was_option=false
                    ;;
            esac
        fi

        last="$line"
    done

    # shellcheck disable=SC2031

    if ! $did_newline; then
        printf "\n"
    fi
}

# Read lines from stdin, look for shell function or variable definition, and
# print function or variable name if found; otherwise, print nothing.
#
# Returns nothing.
parse_code() {
    sed -n \
        -e "s/^$SPACE_RE\(function\)\{0,1\}$SPACE_RE\($NAME_RE\)$SPACE_RE().*$/\2()/p" \
        -e "s/^$SPACE_RE\(export\)\{0,1\}$SPACE_RE\($NAME_RE\)=.*$/\2/p" \
        -e "s/^${SPACE_RE}export$SPACE_RE\($NAME_RE\).*$/\1/p" \
        -e "s/^$SPACE_RE:$SPACE_RE\${\($NAME_RE\):\{0,1\}=.*$/\1/p"
}

# Read lines from stdin, look for TomDoc'd shell functions and variables, and
# pass them to a generator for formatting.
#
# Returns nothing.
parse_tomdoc() {
    doc=
    while read -r line; do
        case "$line" in
        '#'|'# '*)
            doc="$doc$line
"
            ;;
        *)
            test -n "$line" -a -n "$doc" && {
                # Match access level if given.
                test -n "$access" &&
                case "$doc" in
                "# $access:"*)
                    ;;
                *)
                    doc=; continue ;;
                esac

                name="$(printf "%s" "$line" | parse_code)"
                test -n "$name" && "$generate" "$name" "$doc"
            }
            doc=
            ;;
        esac
    done
}

cat -- "$@" | parse_tomdoc

:
