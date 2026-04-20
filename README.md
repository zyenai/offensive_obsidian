# offensive_obsidian
Quick start guide for setting up Obsidian for pentest note taking

# Background

...

# Quick Start

Install and configure everything with a single command:

```bash
# Clone and run
git clone https://github.com/zyenai/offensive_obsidian.git
cd offensive_obsidian
./setup.sh
```

```bash
# Or run directly without cloning
bash <(curl -fsSL https://raw.githubusercontent.com/zyenai/offensive_obsidian/main/setup.sh)
```

```bash
# Custom vault location
./setup.sh --vault ~/pentest/notes
```

The script will:
- Download and install Obsidian (latest release)
- Create an Obsidian vault at `~/obsidian-vault` (or your specified path)
- Install and enable the [Templater](https://github.com/SilentVoid13/Templater) and [Automatic Table of Contents](https://github.com/johansatge/obsidian-automatic-table-of-contents) plugins
- Copy templates and CSS snippets into the vault
- Configure hotkeys automatically

After setup, open Obsidian and select the vault folder.

# Hotkeys

| Hotkey | Action |
|--------|--------|
| `Ctrl+Shift+A` | Insert activity log entry |
| `Ctrl+Shift+O` | Insert outbrief template |
| `Ctrl+Shift+T` | Insert table of contents |

# Usage

- Press `Ctrl+Shift+A` to insert an activity log entry.
- Press `Ctrl+Shift+O` to insert an outbrief template.
- Press `Ctrl+Shift+T` to insert a table of contents.

---

<details>
<summary>Manual installation</summary>

## Install and configure Obsidian

1. Download Obsidian from [https://obsidian.md/download](https://obsidian.md/download)
    - On Windows, download and run `Obsidian*.exe`
    - On Linux, download the `obsidian*.deb` package, then install the package with `sudo apt install obsidian*.deb`

2. Create an Obsidian Vault.

3. Optional: Set up vault syncing through Git, Google Drive, or Obsidian's built-in Sync subscription service.

## Install and configure plugins

2. Install and enable the following community plugins:
    - [Templater](https://github.com/SilentVoid13/Templater)
    - [Automatic Table of Contents](https://github.com/johansatge/obsidian-automatic-table-of-contents)

3. Copy the [config](config) folder in your Obsidian vault.

4. Create a hotkey for the `config/templates/pentest-activity-log` template (I.e., `Ctrl+Shift+A`)

5. Create a hotkey for the `config/templates/pentest-outbrief` template (I.e., `Ctrl+Shift+O`)

6. Create a hotkey and associate it with the `Automatic Table of Contents: Insert table of contents` template.

## Configure CSS snippets

1. Copy the `.css` files in the [css](config/css/) folder to the `.obsidian` folder in your vault.

</details>
