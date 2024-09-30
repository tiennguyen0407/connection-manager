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
    echo "Recent - Top 5 commands"
    tail -n 5 "$HISTORY_FILE" | sort -u | tac | awk '{print NR ": " $0}' | sed 's/$/ - Recent/'
}

# Step 1: Choose organization with preview of its tags
org_selection=$(prepend_recent_selections; jq -r '.[].org' "$COMMANDS_FILE" | sort -u | awk '{print $0}')
org=$(echo "$org_selection" | fzf --height=10 --header="Select Organization or Recent" --preview='export org={} && if [[ "$org" =~ "Top 5" ]]; then tail -n 5 '"$HISTORY_FILE"' | sort -u | tac; elif [[ "$org" =~ "Recent" ]]; then echo $org; else jq -r --arg org $org ".[] | select(.org==\$org) | .tag" '"$COMMANDS_FILE"' | sort -u; fi')

[ -z "$org" ] && exit 1

# If "Recent" was selected, skip to executing a recent command
if [[ "$org" == "Recent - Top 5 commands" ]]; then
    selected_command=$(tail -n 5 "$HISTORY_FILE" | tac | fzf --header="Select a recent command")
    if [[ -n "$selected_command" ]]; then
        eval "$selected_command"
        exit 0
    else
        echo "No recent command selected."
        exit 1
    fi
fi

# Step 2: Choose tag based on organization with preview of its commands
tag=$(jq -r --arg org "$org" '.[] | select(.org==$org) | .tag' "$COMMANDS_FILE" | sort -u | fzf --height=10 --header="Select Tag" --preview="export tag={} && echo \$tag | jq -r --arg tag \$tag '.[] | select(.org==\"$org\" and .tag==\$tag) | .name' $COMMANDS_FILE")
[ -z "$tag" ] && exit 1

# Step 3: Choose name based on tag
name_cmd=$(jq -r --arg org "$org" --arg tag "$tag" '.[] | select(.org==$org and .tag==$tag) | "\(.name)"' "$COMMANDS_FILE" | fzf --height=15 --header="Select Name" --preview="export name={} && echo \$name | jq -r --arg name \$name '.[] | select(.org==\"$org\" and .tag==\"$tag\" and .name==\$name) | .command' $COMMANDS_FILE")

[ -z "$name_cmd" ] && exit 1

# Step 4: Find command and execute
command=$(jq -r --arg org "$org" --arg tag "$tag" --arg name "$name_cmd" '.[] | select(.org==$org and .tag==$tag and .name==$name) | .command' "$COMMANDS_FILE")

if [[ -n "$command" ]]; then
    echo "Executing command: $command"
    update_history "$org - $name_cmd - $command"
    eval "$command"
else
    echo "No command selected."
    exit 1
fi