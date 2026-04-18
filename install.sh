#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd "$(dirname "$0")" && pwd)
package_dir="$repo_dir/package"
metadata_file="$package_dir/metadata.json"

if [[ ! -f "$metadata_file" ]]; then
    echo "Could not find $metadata_file" >&2
    exit 1
fi

plugin_id=$(sed -n 's/.*"Id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$metadata_file" | head -n 1)

if [[ -z "$plugin_id" ]]; then
    echo "Could not determine plasmoid id from $metadata_file" >&2
    exit 1
fi

kpackagetool6 --type Plasma/Applet --remove "$plugin_id" || true
kpackagetool6 --type Plasma/Applet --install "$package_dir"
systemctl --user restart plasma-plasmashell.service

echo "Installed $plugin_id and restarted Plasma shell."