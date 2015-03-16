#!/usr/bin/env bash
#
# Startup wrapper for tmux.
#

PATH="~/bin:/usr/local/bin:/usr/local/sbin:${PATH}"

# abort if we're already inside a TMUX session
[ "${TMUX}" == "" ] || exit 0

# startup a "default" session if none currently exists
(tmux has-session -t _default &> /dev/null) || (tmux new-session -s _default -d &> /dev/null)

# present menu for user to choose which workspace to open
PS3="Please choose your session: "
options=($(tmux list-sessions -F "#S") "NEW SESSION" "BASH")
echo "Available TMUX sessions"
echo "-----------------------"
echo " "
select opt in "${options[@]}"
do
  case $opt in
    "NEW SESSION")
      read -p "Enter new session name: " SESSION_NAME
      tmux new -s "$SESSION_NAME"
      break
      ;;
    "BASH")
      bash --login
      break;;
    *)
      tmux attach-session -t $opt
      break
      ;;
  esac
done
