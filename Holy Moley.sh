#!/bin/sh
printf '\033c\033]0;%s\a' Holy Moley
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Holy Moley.x86_64" "$@"
