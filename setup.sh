#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="https://raw.githubusercontent.com/zyenai/offensive_obsidian/main"
VAULT_PATH="${OBSIDIAN_VAULT:-$HOME/obsidian-vault}"
FORCE=false
SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [VAULT_PATH]

Download, install, and configure Obsidian for pentest note-taking.

Options:
  -v, --vault PATH   Vault directory (default: ~/obsidian-vault)
  --force            Overwrite existing config files
  -h, --help         Show this message

Environment:
  OBSIDIAN_VAULT     Alternative way to set vault path

Examples:
  ./setup.sh
  ./setup.sh --vault ~/pentest/notes
  bash <(curl -fsSL ${REPO_RAW_BASE}/setup.sh) --vault ~/notes
EOF
}

info()    { echo "[*] $*"; }
success() { echo "[+] $*"; }
warn()    { echo "[!] $*" >&2; }
die()     { echo "[!] ERROR: $*" >&2; exit 1; }

# Copy from local repo or download from GitHub
copy_or_download() {
    local rel_path="$1"
    local dest="$2"
    if [[ -d "$SCRIPT_DIR/config" ]]; then
        cp "$SCRIPT_DIR/$rel_path" "$dest"
    else
        curl -fsSL --retry 3 --retry-delay 2 "$REPO_RAW_BASE/$rel_path" -o "$dest"
    fi
}

# ---------------------------------------------------------------------------
# parse_args
# ---------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--vault) VAULT_PATH="$2"; shift 2 ;;
            --force)    FORCE=true; shift ;;
            -h|--help)  usage; exit 0 ;;
            -*)         die "Unknown option: $1" ;;
            *)          VAULT_PATH="$1"; shift ;;
        esac
    done
    # Expand leading ~
    VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
}

# ---------------------------------------------------------------------------
# detect_platform
# ---------------------------------------------------------------------------
detect_platform() {
    local os
    os="$(uname -s)"
    case "$os" in
        Linux) ;;
        *)     die "Unsupported platform: $os. Only Linux is currently supported." ;;
    esac
    if ! command -v dpkg &>/dev/null; then
        die "dpkg not found. This script requires a Debian/Ubuntu-based system."
    fi
    if ! command -v curl &>/dev/null; then
        die "curl is required but not installed. Run: sudo apt install curl"
    fi
}

# ---------------------------------------------------------------------------
# install_obsidian
# ---------------------------------------------------------------------------
install_obsidian() {
    # libasound2 is an undeclared Electron dependency; ensure it's present regardless
    $SUDO apt-get install -y libasound2t64 2>/dev/null \
        || $SUDO apt-get install -y libasound2 2>/dev/null \
        || warn "Could not install libasound2 — Obsidian may fail to start"

    if dpkg -s obsidian &>/dev/null 2>&1; then
        info "Obsidian is already installed, skipping."
        return 0
    fi

    info "Fetching latest Obsidian release info..."
    local version
    version="$(curl -fsI --retry 3 --retry-delay 2 \
        https://github.com/obsidianmd/obsidian-releases/releases/latest \
        | grep -i '^location:' | sed 's|.*/tag/||' | tr -d '[:space:]')"
    [[ -n "$version" ]] || die "Could not determine latest Obsidian version."

    local ver="${version#v}"
    local arch
    arch="$(dpkg --print-architecture)"  # amd64 or arm64

    local url="https://github.com/obsidianmd/obsidian-releases/releases/download/${version}/obsidian_${ver}_${arch}.deb"
    local tmp
    tmp="$(mktemp /tmp/obsidian_XXXXXX.deb)"

    info "Downloading Obsidian ${version} (${arch})..."
    curl -fsSL --retry 3 --retry-delay 2 -o "$tmp" "$url" \
        || die "Failed to download Obsidian from: $url"

    info "Installing Obsidian..."
    $SUDO dpkg -i "$tmp" || $SUDO apt-get install -f -y
    rm -f "$tmp"
    success "Obsidian ${version} installed."
}

# ---------------------------------------------------------------------------
# create_vault_structure
# ---------------------------------------------------------------------------
create_vault_structure() {
    if [[ -d "$VAULT_PATH/.obsidian" ]] && [[ "$FORCE" == false ]]; then
        warn "Vault already exists at $VAULT_PATH. Use --force to overwrite config."
    fi

    mkdir -p \
        "$VAULT_PATH/.obsidian/plugins/templater-obsidian" \
        "$VAULT_PATH/.obsidian/plugins/obsidian-automatic-table-of-contents" \
        "$VAULT_PATH/.obsidian/snippets" \
        "$VAULT_PATH/templates"

    info "Vault structure created at $VAULT_PATH"
}

# ---------------------------------------------------------------------------
# install_plugin <plugin-id> <owner/repo>
# ---------------------------------------------------------------------------
install_plugin() {
    local plugin_id="$1"
    local github_repo="$2"
    local plugin_dir="$VAULT_PATH/.obsidian/plugins/$plugin_id"

    if [[ -f "$plugin_dir/main.js" ]] && [[ "$FORCE" == false ]]; then
        info "Plugin $plugin_id already installed, skipping."
        return 0
    fi

    info "Installing plugin: $plugin_id..."
    local version
    version="$(curl -fsI --retry 3 --retry-delay 2 \
        "https://github.com/${github_repo}/releases/latest" \
        | grep -i '^location:' | sed 's|.*/tag/||' | tr -d '[:space:]')" \
        || die "Failed to fetch release info for $plugin_id"
    [[ -n "$version" ]] || die "Could not determine latest version of $plugin_id"

    local base_url="https://github.com/${github_repo}/releases/download/${version}"
    for asset in main.js manifest.json styles.css; do
        local asset_url="${base_url}/${asset}"
        if curl -fsI --retry 3 --retry-delay 2 "$asset_url" &>/dev/null; then
            curl -fsSL --retry 3 --retry-delay 2 -o "$plugin_dir/$asset" "$asset_url" \
                || die "Failed to download $asset for $plugin_id"
        fi
    done
    success "Plugin $plugin_id installed."
}

# ---------------------------------------------------------------------------
# copy_static_configs
# ---------------------------------------------------------------------------
copy_static_configs() {
    info "Copying CSS snippets..."
    for css_file in callout-10vh callout-15vh callout-25ch callout-50vh formats; do
        local dest="$VAULT_PATH/.obsidian/snippets/${css_file}.css"
        if [[ ! -f "$dest" ]] || [[ "$FORCE" == true ]]; then
            copy_or_download "config/css/${css_file}.css" "$dest"
        fi
    done

    info "Copying templates..."
    for tpl in pentest-activity-log pentest-outbrief; do
        local dest="$VAULT_PATH/templates/${tpl}.md"
        if [[ ! -f "$dest" ]] || [[ "$FORCE" == true ]]; then
            copy_or_download "config/templates/${tpl}.md" "$dest"
        fi
    done

    info "Writing Obsidian config files..."
    local obsidian_dir="$VAULT_PATH/.obsidian"

    if [[ ! -f "$obsidian_dir/hotkeys.json" ]] || [[ "$FORCE" == true ]]; then
        copy_or_download "config/obsidian/hotkeys.json" "$obsidian_dir/hotkeys.json"
    fi

    if [[ ! -f "$obsidian_dir/app.json" ]] || [[ "$FORCE" == true ]]; then
        copy_or_download "config/obsidian/app.json" "$obsidian_dir/app.json"
    fi
}

# ---------------------------------------------------------------------------
# merge_community_plugins  (idempotent: adds only missing plugin IDs)
# ---------------------------------------------------------------------------
merge_community_plugins() {
    local dest="$VAULT_PATH/.obsidian/community-plugins.json"
    local required=("templater-obsidian" "obsidian-automatic-table-of-contents")

    if [[ ! -f "$dest" ]]; then
        copy_or_download "config/obsidian/community-plugins.json" "$dest"
        return 0
    fi

    # Append any missing plugin IDs using Python (available on all Debian/Ubuntu/Kali systems)
    python3 - "$dest" "${required[@]}" <<'PYEOF'
import json, sys
dest = sys.argv[1]
required = sys.argv[2:]
with open(dest) as f:
    plugins = json.load(f)
changed = False
for p in required:
    if p not in plugins:
        plugins.append(p)
        changed = True
if changed:
    with open(dest, 'w') as f:
        json.dump(plugins, f, indent=2)
PYEOF
}

# ---------------------------------------------------------------------------
# write_templater_data_json
# ---------------------------------------------------------------------------
write_templater_data_json() {
    local dest="$VAULT_PATH/.obsidian/plugins/templater-obsidian/data.json"
    if [[ -f "$dest" ]] && [[ "$FORCE" == false ]]; then
        info "Templater data.json already exists, skipping."
        return 0
    fi

    cat > "$dest" <<EOF
{
  "command_timeout": 5,
  "enable_folder_templates": true,
  "enabled_templates_hotkeys": [
    {
      "hotkey": {"modifiers": ["Mod","Shift"], "key": "A"},
      "template_file": "templates/pentest-activity-log.md"
    },
    {
      "hotkey": {"modifiers": ["Mod","Shift"], "key": "O"},
      "template_file": "templates/pentest-outbrief.md"
    }
  ],
  "folder_templates": [],
  "syntax_highlighting": true,
  "template_folder": "templates",
  "trigger_on_file_creation": false
}
EOF
}

# ---------------------------------------------------------------------------
# check_obsidian_running
# ---------------------------------------------------------------------------
check_obsidian_running() {
    if pgrep -x obsidian &>/dev/null; then
        warn "Obsidian is currently running. Close it before opening the new vault."
    fi
}

# ---------------------------------------------------------------------------
# print_summary
# ---------------------------------------------------------------------------
print_summary() {
    echo ""
    success "Setup complete!"
    echo ""
    echo "  Vault:    $VAULT_PATH"
    echo "  Plugins:  Templater, Automatic Table of Contents"
    echo "  Hotkeys:"
    echo "    Ctrl+Shift+A  — Insert activity log entry"
    echo "    Ctrl+Shift+O  — Insert outbrief template"
    echo "    Ctrl+Shift+T  — Insert table of contents"
    echo ""
    echo "  Next step: Open Obsidian and select '$VAULT_PATH' as your vault."
    echo ""
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"

    echo ""
    echo "offensive_obsidian setup"
    echo "========================"
    echo ""
    info "Vault path: $VAULT_PATH"
    echo ""

    detect_platform
    check_obsidian_running
    install_obsidian
    create_vault_structure
    install_plugin "templater-obsidian" "SilentVoid13/Templater"
    install_plugin "obsidian-automatic-table-of-contents" \
        "johansatge/obsidian-automatic-table-of-contents"
    copy_static_configs
    write_templater_data_json
    merge_community_plugins
    print_summary
}

main "$@"
