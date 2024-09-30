#!/bin/bash

# Updated path for the JSON file containing SSH commands
COMMANDS_FILE="/Users/mac/devops/tools/connection-manager/list.json"

# Step 1: Choose organization with a preview showing available tags in this organization
org=$(jq -r '.[].org' $COMMANDS_FILE | sort -u | fzf --height=10 --header="Select Organization" --preview='export org={} && echo $org | jq -r --arg org $org ".[] | select(.org==\$org) | .tag" '"$COMMANDS_FILE"' | sort -u')

# Abort if nothing is selected
[ -z "$org" ] && exit 1

# Step 2: Choose tag based on organization with a preview showing available names in this tag
tag=$(jq -r --arg org "$org" '[.[] | select(.org==$org).tag] | unique[]' $COMMANDS_FILE | fzf --height=10 --header="Select Tag" --preview="export tag={} && echo \$tag | jq -r --arg tag \$tag '.[] | select(.org==\"$org\" and .tag==\$tag) | .name' $COMMANDS_FILE")

# Abort if nothing is selected
[ -z "$tag" ] && exit 1

# Step 3: Choose name based on tag with a preview of the Name
name_cmd=$(jq -r --arg org "$org" --arg tag "$tag" '.[] | select(.org==$org and .tag==$tag) | "\(.name)"' $COMMANDS_FILE | fzf --height=15 --header="Select Name" --preview="export name={} && echo \$name | jq -r --arg name \$name '.[] | select(.org==\"$org\" and .tag==\"$tag\" and .name==\$name) | .command' $COMMANDS_FILE")

# Extract command and execute
command=$(echo "$name_cmd" | sed 's/.* - //')

if [[ -n "$command" ]]; then
    echo "Executing command: $command"
    eval "$command"
else
    echo "No command selected."
fi