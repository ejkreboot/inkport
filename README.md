# Inkport

![ShellCheck](https://img.shields.io/badge/lint-shellcheck-brightgreen?logo=gnu-bash)
![License](https://img.shields.io/github/license/ejkreboot/inkport)
![Issues](https://img.shields.io/github/issues/ejkreboot/inkport)
![CI](https://github.com/ejkreboot/inkport/actions/workflows/test.yml/badge.svg)

**Inkport** is a command-line tool for uploading and registering custom templates on the reMarkable 2 tablet. It safely manages template files and updates `templates.json` to make new templates available on the device.

---

## 🛡️ Disclaimer

This tool is a work in progress. It is provided **as-is** with no guarantees or warranties of any kind — including fitness for a particular purpose or protection against device damage. Use at your own risk.

A malformed `templates.json` may cause templates to become unavailable. While reasonable effort has been made to prevent this tool from rendering your device unusable, I cannot guarantee compatibility with all use cases.

---

## 🚀 Features

- Upload `.svg` templates to the reMarkable via SSH
- Automatically updates `templates.json` with metadata
- Supports per-template `.json` metadata files
- Friendly icon name to Unicode glyph mapping
- **Dry-run mode** to preview all actions before making changes
- **Automatic backup** of original `templates.json` on first use
- **Restore mode** to revert to factory templates
- **OS version check** (requires 3.18.1.1 or later)

---

## 📦 Installation

### 🔹 Recommended: Interactive installer

```bash
./install.sh
```

This will:

- Prompt for your reMarkable’s IP address and SSH username
- Write a config file to `.remarkable/config.json`
- Optionally copy your SSH public key to the device
- Optionally install the `inkport` command to `/usr/local/bin` (if `make` is available)

### 🔹 Developer install (requires `make`)

```bash
make install   # Installs inkport to /usr/local/bin
```

To uninstall:

```bash
make uninstall
```

To run the interactive setup from Make:

```bash
make setup
```

---

## 🧐 Usage

```bash
inkport [options] <template.svg> [meta.json]
```

### Common Options

| Option | Description                                        |
|--------|----------------------------------------------------|
| `-n`   | Set a user-facing display name for the template    |
| `-i`   | Specify an icon name (looked up in `iconmap.json`) |
| `-c`   | Specify a category name (e.g. `creative`)          |
| `-h`   | Override host from config                          |
| `-u`   | Override user from config                          |
| `-d`   | Dry-run mode — no uploads, just simulation         |
| `-z`   | Restore the original `templates.json` from backup  |

### Example

```bash
inkport -n "Music Journal" -i music -c creative music_template.svg music_template.json
```

---

## 📁 Configuration Directory

All persistent configuration lives in:

```
.remarkable/
├── config.json      # SSH credentials and default metadata values
└── iconmap.json     # (Optional) Maps icon names to Unicode glyphs
```

---

## ♻️ Batch Mode Examples

Upload all `.svg` files in a directory:

```bash
ls *.svg | xargs -n 1 ./inkport.sh
```

Or use metadata files:

```bash
for f in *.svg; do ./inkport.sh "$f" "${f%.svg}.json"; done
```

---

## 📝 Optional Metadata File

You may create a `template.json` file for each `.svg` template with fields like:

```json
{
  "iconCode": "music",
  "orientation": "portrait",
  "categories": ["creative"]
}
```

---

## ♻️ Restore Original Templates

Inkport backs up your factory `templates.json` the first time it's run for a given OS version.

To restore the original template list:

```bash
inkport -z
```

This will replace `templates.json` with the backup stored in:

```
/usr/share/remarkable/templates/.restore/<OS_VERSION>
```

> ℹ️ This will **not delete** any `.svg` files, but it will reset the UI to show only the factory templates.

---

## 🧪 Developer Utilities

Use `make` for development tasks:

```bash
make check      # Run ShellCheck
make lint       # Alias for check
make test       # Run Bats tests
make install    # Install inkport CLI
make uninstall  # Remove inkport CLI
make setup      # Run install.sh
```

---

## 💬 Contributions

Bug reports, improvements, and icon mapping help are welcome.

Built with curiosity and caffeine ☕️

