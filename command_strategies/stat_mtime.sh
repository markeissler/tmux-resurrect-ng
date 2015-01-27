#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

FILE_PATH="$1"

exit_safely_if_empty_filepath() {
	if [ -z "$FILE_PATH" ]; then
		exit 1
	fi
}

stat_command_flags() {
	case $(uname -s) in
		Darwin | OSX) ;&
		FreeBSD) ;&
		OpenBSD)
 			echo "-f \"%m\""
 			;;
		*)
			echo "-c%X"
			;;
	esac
}

full_command() {
	stat "$(stat_command_flags)" "${FILE_PATH}"
	return $?
}

main() {
	# exit_safely_if_empty_filepath
	full_command
	return $?
}
main
exit $?
