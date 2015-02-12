# restore_helpers.sh
#
# requires:
#   variables.sh
#   helpers.sh
#   process_restore_helpers.sh
#

# Global variable.
# Used during the restore: if a pane already exists from before, it is
# saved in the array in this variable. Later, process running in existing pane
# is also not restored. That makes the restoration process more idempotent.
EXISTING_PANES_VAR=""

is_line_type() {
  local line_type="$1"
  local line="$2"
  echo "$line" |
    \grep -q "^$line_type"
}

check_saved_session_exists() {
  local resurrect_file="$(last_resurrect_file)"
  if [ ! -f $resurrect_file ]; then
    return 1
  fi
}

pane_exists() {
  local session_name="$1"
  local window_number="$2"
  local pane_index="$3"
  tmux list-panes -t "${session_name}:${window_number}" -F "#{pane_index}" 2>/dev/null |
    \grep -q "^$pane_index$"
}

register_existing_pane() {
  local session_name="$1"
  local window_number="$2"
  local pane_index="$3"
  local pane_custom_id="${session_name}:${window_number}:${pane_index}"
  local delimiter=$'\t'
  EXISTING_PANES_VAR="${EXISTING_PANES_VAR}${delimiter}${pane_custom_id}"
}

is_pane_registered_as_existing() {
  local session_name="$1"
  local window_number="$2"
  local pane_index="$3"
  local pane_custom_id="${session_name}:${window_number}:${pane_index}"
  [[ "$EXISTING_PANES_VAR" =~ "$pane_custom_id" ]]
}

window_exists() {
  local session_name="$1"
  local window_number="$2"
  tmux list-windows -t "$session_name" -F "#{window_index}" 2>/dev/null |
    \grep -q "^$window_number$"
}

session_exists() {
  local session_name="$1"
  tmux has-session -t "$session_name" 2>/dev/null
}

first_window_num() {
  tmux show -gv base-index
}

tmux_socket() {
  echo $TMUX | cut -d',' -f1
}

new_window() {
  local session_name="$1"
  local window_number="$2"
  local window_name="$3"
  local dir="$4"
  tmux new-window -d -t "${session_name}:${window_number}" -n "$window_name" -c "$dir"
}

new_session() {
  local session_name="$1"
  local window_number="$2"
  local window_name="$3"
  local dir="$4"
  TMUX="" tmux -S "$(tmux_socket)" new-session -d -s "$session_name" -n "$window_name" -c "$dir"
  # change first window number if necessary
  local created_window_num="$(first_window_num)"
  if [ $created_window_num -ne $window_number ]; then
    tmux move-window -s "${session_name}:${created_window_num}" -t "${session_name}:${window_number}"
  fi
}

new_pane() {
  local session_name="$1"
  local window_number="$2"
  local window_name="$3"
  local dir="$4"
  tmux split-window -t "${session_name}:${window_number}" -c "$dir"
  # minimize window so more panes can fit
  tmux resize-pane  -t "${session_name}:${window_number}" -U "999"
}

restore_pane() {
  local pane="$1"
  while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command pane_full_command; do
    dir="$(remove_first_char "$dir")"
    window_name="$(remove_first_char "$window_name")"
    pane_full_command="$(remove_first_char "$pane_full_command")"
    if pane_exists "$session_name" "$window_number" "$pane_index"; then
      # Pane exists, no need to create it!
      # Pane existence is registered. Later, it's process also isn't restored.
      register_existing_pane "$session_name" "$window_number" "$pane_index"
    elif window_exists "$session_name" "$window_number"; then
      new_pane "$session_name" "$window_number" "$window_name" "$dir"
    elif session_exists "$session_name"; then
      new_window "$session_name" "$window_number" "$window_name" "$dir"
    else
      new_session "$session_name" "$window_number" "$window_name" "$dir"
    fi
  done < <(echo "$pane")
}

restore_state() {
  local state="$1"
  echo "$state" |
  while IFS=$'\t' read line_type client_session client_last_session; do
    tmux switch-client -t "$client_last_session"
    tmux switch-client -t "$client_session"
  done
}

restore_all_panes() {
  while read line; do
    if is_line_type "pane" "$line"; then
      restore_pane "$line"
    fi
  done < $(last_resurrect_file)
}

restore_pane_history() {
  local pane_id="$1"
  local pane_command="$2"

  if is_pane_registered_as_existing "$pane_id"; then return 0; fi

  if [ "$pane_command" = "bash" ]; then
    local pane_id="$session_name:$window_number.$pane_index"
    # tmux send-keys has -R option that should reset the terminal.
    # However, appending 'clear' to the command seems to work more reliably.
    local read_command="history -r '$(last_pane_history_file "$pane_id")'; clear"
    tmux send-keys -t "$pane_id" "$read_command" C-m
  fi
}

restore_pane_histories() {
  awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ { print $2, $3, $7, $10; }' $(last_resurrect_file) |
    while IFS=$'\t' read session_name window_number pane_index pane_command; do
      local pane_id="$session_name:$window_number.$pane_index"
      restore_pane_history "$pane_id" "$pane_command"
    done
}

restore_pane_buffer() {
  local pane_id="$1"
  local pane_command="$2"

  if is_pane_registered_as_existing "$pane_id"; then return 0; fi

  if [ "$pane_command" = "bash" ]; then
    local pane_id="$session_name:$window_number.$pane_index"
    local buffer_file_path="$(last_pane_buffer_file "$pane_id")"
    # space before 'cat' is intentional and prevents the command from
    # being added to history (provided HISTCONTROL=ignorespace/ignoreboth
    # has been set in bashrc.
    tmux send-keys -t "$pane_id" " clear && tmux clear-history" C-m
    local pane_tty="$(get_pane_tty "$pane_id")"
    if [ -n "$pane_tty" ]; then
      # append directly to tty (avoids cat command output)
      cat "$buffer_file_path" >> "$pane_tty"
    else
      # fall back to cat'ing in terminal if not tty found
      tmux send-keys -t "$pane_id" " cat \"$buffer_file_path\"" C-m
    fi
  fi
}

restore_pane_buffers() {
  awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ { print $2, $3, $7, $10; }' $(last_resurrect_file) |
    while IFS=$'\t' read session_name window_number pane_index pane_command; do
      local pane_id="$session_name:$window_number.$pane_index"
      restore_pane_buffer "$pane_id" "$pane_command"
    done
}

restore_all_pane_processes() {
  if restore_pane_processes_enabled; then
    local pane_full_command
    awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ && $11 !~ "^:$" { print $2, $3, $7, $8, $11; }' $(last_resurrect_file) |
      while IFS=$'\t' read session_name window_number pane_index dir pane_full_command; do
        dir="$(remove_first_char "$dir")"
        pane_full_command="$(remove_first_char "$pane_full_command")"
        restore_pane_process "$pane_full_command" "$session_name" "$window_number" "$pane_index" "$dir"
      done
  fi
}

restore_pane_layout_for_each_window() {
  \grep '^window' $(last_resurrect_file) |
    while IFS=$'\t' read line_type session_name window_number window_active window_flags window_layout; do
      tmux select-layout -t "${session_name}:${window_number}" "$window_layout"
    done
}

restore_active_pane_for_each_window() {
  awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ && $9 == 1 { print $2, $3, $7; }' $(last_resurrect_file) |
    while IFS=$'\t' read session_name window_number active_pane; do
      tmux switch-client -t "${session_name}:${window_number}"
      tmux select-pane -t "$active_pane"
    done
}

restore_active_and_alternate_windows() {
  awk 'BEGIN { FS="\t"; OFS="\t" } /^window/ && $5 ~ /[*-]/ { print $2, $4, $3; }' $(last_resurrect_file) |
    sort -u |
    while IFS=$'\t' read session_name active_window window_number; do
      tmux switch-client -t "${session_name}:${window_number}"
    done
}

restore_active_and_alternate_sessions() {
  while read line; do
    if is_line_type "state" "$line"; then
      restore_state "$line"
    fi
  done < $(last_resurrect_file)
}