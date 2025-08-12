#!/bin/bash

# Path to the JSON file containing SSH commands
COMMANDS_FILE="/Users/mac/devops/tools/connection-manager/list.json"
# Path to the history file storing recent selections
HISTORY_FILE="/Users/mac/devops/tools/connection-manager/ssh_history.log"

# Ensure the history file exists
touch "$HISTORY_FILE"

# Function to append selection to the history file and keep only the newest entry for each name
update_history() {
    # Extract name from the input
    local name=$(echo "$1" | cut -d'|' -f1 | xargs)
    local entry="$1"
    
    # Create a temporary file
    local temp_file="${HISTORY_FILE}.tmp"
    > "$temp_file"
    
    # Keep track of names we've seen
    local seen_names=()
    
    # Add the new entry first (so it's the newest for this name)
    echo "$entry" >> "$temp_file"
    seen_names+=("$name")
    
    # Go through existing history and only keep entries with names we haven't seen yet
    while IFS= read -r line; do
        local line_name=$(echo "$line" | cut -d'|' -f1 | xargs)
        
        # Check if we've already seen this name
        local skip=false
        for seen in "${seen_names[@]}"; do
            if [[ "$seen" == "$line_name" ]]; then
                skip=true
                break
            fi
        done
        
        # If we haven't seen this name, keep the entry and mark as seen
        if [[ "$skip" == "false" ]]; then
            echo "$line" >> "$temp_file"
            seen_names+=("$line_name")
        fi
    done < "$HISTORY_FILE"
    
    # Replace the original file with our filtered version
    # Limit to the most recent 20 entries overall
    tail -n 20 "$temp_file" > "$HISTORY_FILE"
    rm "$temp_file"
}

# Function to prepend recent commands for fzf
prepend_recent_selections() {
    if [ -s "$HISTORY_FILE" ]; then
        echo "Recent - Top 5 commands"
        # remove duplicate lines and empty lines, then sort and reverse the list
        cat "$HISTORY_FILE" | sort -u | tail -n 5 | tac | grep '.' | awk '{print NR ": " $0}'
    fi
}

# Get all commands with preview
selection=$(prepend_recent_selections; jq -r '.[] | .name + " | " + .command' "$COMMANDS_FILE" | sort -u | awk '{print $0}')
selected=$(echo "$selection" | fzf --height=10 --header="Select Connection or Recent" --preview='if [[ "{}" =~ "Top 5" ]]; then tail -n 5 '"$HISTORY_FILE"' | sort -u | tac; elif [[ "{}" =~ "ssh" ]]; then echo {}; fi')

if [[ -z "$selected" ]]; then
    exit 1
fi

# If a command was selected directly
if [[ "$selected" =~ " | ssh" ]]; then
    name=$(echo "$selected" | cut -d'|' -f1 | xargs)
    command=$(echo "$selected" | cut -d'|' -f2- | xargs)
    
    echo "Executing command: $command"
    update_history "$name | $command"
    eval "$command"
    exit 0
fi

# If "Recent" was selected, skip to executing a recent command
if [[ "$selected" == "Recent - Top 5 commands" ]]; then
    selected_command=$(tail -n 5 "$HISTORY_FILE" | tac | fzf --header="Select a recent command" --preview="echo {} | cut -d'|' -f2-")
    
    if [[ -n "$selected_command" ]]; then
        name=$(echo "$selected_command" | cut -d'|' -f1 | xargs)
        command=$(echo "$selected_command" | cut -d'|' -f2- | xargs)
        
        echo "Executing command: $command"
        update_history "$selected_command"
        eval "$command"
        exit 0
    else
        echo "No recent command selected."
        exit 1
    fi
fi

# If we got here, something unexpected happened
echo "No valid selection made."
exit 1