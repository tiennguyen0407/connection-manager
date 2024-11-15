#!/bin/bash

# Path to the JSON file containing SSH commands
COMMANDS_FILE="/Users/mac/devops/tools/connection-manager/list.json"
# Path to the history file storing recent selections
HISTORY_FILE="/Users/mac/devops/tools/connection-manager/ssh_history.log"

# Ensure the history file exists
touch "$HISTORY_FILE"

# Function to append selection to the history file and keep only the last 20 entries
update_history() {
    echo "$1" >> "$HISTORY_FILE"
    tail -n 20 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

# Function to prepend recent commands for fzf
prepend_recent_selections() {
    if [ -s "$HISTORY_FILE" ]; then
        echo "Recent - Top 5 commands"
        # remove duplicate lines and empty lines, then sort and reverse the list
        cat "$HISTORY_FILE" | sort -u | tail -n 5 | tac | grep '.' | awk '{print NR ": " $0}'
    fi
}

# Step 1: Choose organization with preview of its name
org_selection=$(prepend_recent_selections; jq -r '.[].org' "$COMMANDS_FILE" | sort -u | awk '{print $0}')
org=$(echo "$org_selection" | fzf --height=10 --header="Select Organization or Recent" --preview='export org={} && if [[ "$org" =~ "Top 5" ]]; then tail -n 5 '"$HISTORY_FILE"' | sort -u | tac; elif [[ "$org" =~ "ssh" ]]; then echo $org; else jq -r --arg org $org ".[] | select(.org==\$org) | .name" '"$COMMANDS_FILE"' | sort -u; fi')

if [[ "$org" =~ "ssh" ]]; then

    command=$(echo "$org" | cut -d'|' -f3)

    echo "Executing command: $command"
    save_history="${org:3}"
    update_history "$save_history"
    eval "$command"
    exit 0
fi

[ -z "$org" ] && exit 1

# If "Recent" was selected, skip to executing a recent command
if [[ "$org" == "Recent - Top 5 commands" ]]; then
    selected_command=$(tail -n 5 "$HISTORY_FILE" | tac | fzf --header="Select a recent command" --preview="echo {} | cut -d'|' -f3")
    echo "$selected_command"
    command=$(echo "$selected_command" | cut -d'|' -f3)

    update_history "$selected_command"

    if [[ -n "$command" ]]; then
        echo "Executing command: $command"
        eval "$command"
        exit 0
    else
        echo "No recent command selected."
        exit 1
    fi
fi

# Step 2: Choose name based on organization with preview of its commands
name_cmd=$(jq -r --arg org "$org" '.[] | select(.org==$org) | .name' "$COMMANDS_FILE" | sort -u | fzf --height=10 --header="Select Name" --preview="export name={} && echo \$name | jq -r --arg name \$name '.[] | select(.org==\"$org\" and .name==\$name) | .command' $COMMANDS_FILE")
[ -z "$name_cmd" ] && exit 1

# Step 4: Find command and execute
command=$(jq -r --arg org "$org" --arg name "$name_cmd" '.[] | select(.org==$org and .name==$name) | .command' "$COMMANDS_FILE")

if [[ -n "$command" ]]; then
    echo "Executing command: $command"
    update_history "$org | $name_cmd | $command"
    eval "$command"
else
    echo "No command selected."
    exit 1
fi