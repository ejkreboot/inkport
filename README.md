# 🖋️ Inkport

**Inkport** is a command-line tool for uploading and registering custom templates on the reMarkable 2 tablet. It safely manages template files and updates `templates.json` to make new templates available on the device.

---

## 🚀 Features

- Upload `.svg` templates to the reMarkable via SSH
- Automatically updates `templates.json` with metadata
- Supports per-template `.json` metadata files
- Uses friendly icon names mapped to Unicode glyphs
- Dry-run mode for previewing changes without applying them
- **Automatic backup** of original `templates.json` upon first run
- **Restore mode** to revert to the factory template list
- **Version check** to ensure compatibility with OS `3.18.1.1` or higher

---

## 📦 Installation

Clone this repository:

```bash
git clone https://github.com/yourname/inkport.git
cd inkport
```

Run the install script:

```bash
./install.sh
```

This will:

- Prompt you for the IP address and SSH username of your reMarkable
- Write a config file to `.remarkable/config.json`
- Optionally copy your SSH public key to the device for passwordless access

---

## 🧠 Usage

```bash
./inkport.sh [options] <template.svg> [meta.json]
```

### Common Options

| Option | Description                                        |
| ------ | -------------------------------------------------- |
| `-n`   | Set a user-facing display name for the template    |
| `-i`   | Specify an icon name (looked up in `iconmap.json`) |
| `-c`   | Specify a category name (e.g. `creative`)          |
| `-h`   | Override host from config                          |
| `-u`   | Override user from config                          |
| `-d`   | Dry-run mode — no uploads, just simulate           |
| `-z`   | Restore original `templates.json` from backup      |

### Example

```bash
./inkport.sh -n "Music Journal" -i music -c creative music_template.svg music_template.json
```

This command uploads `music_template.svg`, applies metadata, sets the display name to "Music Journal", and assigns it the `music` icon and `creative` category.

---

## 📁 Config Directory

All persistent configuration lives in:

```
.remarkable/
├── config.json      # SSH and default metadata values
└── iconmap.json     # (Optional) Maps icon names to Unicode glyphs
```

---

## 🔁 Batch Mode Example

You can upload multiple templates using `xargs`:

```bash
ls *.svg | xargs -n 1 ./inkport.sh
```

Or include metadata if each SVG has a matching `.json`:

```bash
for f in *.svg; do ./inkport.sh "$f" "${f%.svg}.json"; done
```

---

## 📝 Metadata File (Optional)

For each template (e.g. `template.svg`), you may create a `template.json` file with:

```json
{
  "iconCode": "music",
  "orientation": "portrait",
  "categories": ["creative"]
}
```

---

## ♻️ Restore Original Templates

Inkport will automatically back up your factory `templates.json` the first time it runs on a given OS version.

To restore the original template list:

```bash
./inkport.sh -z
```

This will overwrite `templates.json` with the original version stored in:

```bash
/usr/share/remarkable/templates/.restore/<OS_VERSION>
```

> Note: This will **not delete** any `.svg` files, but will reset the interface to show only the original templates.

---

## 🛡️ Disclaimer

> This tool works for me — it is provided **as-is** with no guarantees.\
> Use at your own risk.\
> A malformed `templates.json` may make custom templates unavailable,\
> but **should not brick your device**.\
> That said, **back up your files** and proceed carefully.

---

## 💬 Contributions

Bug reports, improvements, and icon mapping help are welcome.

Built with curiosity and caffeine ☕

