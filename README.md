# 📦 archives.yazi

**The ultimate archive management plugin for [Yazi](https://github.com/sxyazi/yazi) file manager**

Transform your file management workflow with seamless compression and extraction capabilities, just like the beloved ranger-archives but designed specifically for Yazi's modern architecture.

## Features

* 🚀 **Lightning Fast** - Intelligent parallel compression tool detection (pigz, pbzip2, pixz) for maximum performance
* 🌍 **Universal Compatibility** - Works flawlessly across Linux, macOS, and Windows
* 📋 **Extensive Format Support** - 20+ archive formats including tar.gz, tar.bz2, tar.xz, zip, 7z, rar, and more
* 🧠 **Smart Tool Selection** - Automatically detects and prioritizes the best available compression tools
* 🔄 **Graceful Fallbacks** - Always finds an alternative when your preferred tool isn't available
* ⚡ **Minimal Configuration** - Works out of the box with intelligent defaults

## Supported Formats

### Archive Formats

- **ZIP**: .zip (via zip/unzip or 7z)
- **7-Zip**: .7z (via 7z)
- **RAR**: .rar (via rar/unrar or 7z)
- **TAR**: .tar (via tar)

### Compressed Archives (tar-based)

- **Gzip**: .tar.gz, .tgz (via tar + gzip/pigz)
- **Bzip2**: .tar.bz2, .tbz2 (via tar + bzip2/pbzip2/lbzip2)
- **XZ**: .tar.xz, .txz (via tar + xz/pixz)
- **LZ4**: .tar.lz4 (via tar + lz4)
- **Zstandard**: .tar.zst (via tar + zstd)

### Single-file Compression

- **.gz**: via gzip/pigz
- **.bz2**: via bzip2/pbzip2/lbzip2
- **.xz**: via xz/pixz

## 🚀 Quick Installation

### Using Yazi Package Manager (Recommended)

```bash
ya pack add maximtrp/archives
```

### Manual Installation

```bash
# Linux/macOS
mkdir -p ~/.config/yazi/plugins
git clone https://github.com/maxim/archives.yazi.git ~/.config/yazi/plugins/archives.yazi

# Windows
mkdir %AppData%\yazi\config\plugins
git clone https://github.com/maxim/archives.yazi.git %AppData%\yazi\config\plugins\archives.yazi
```

### Alternative Installation

If you prefer to copy manually:

```bash
# Linux/macOS
mkdir -p ~/.config/yazi/plugins
cp -r archives.yazi ~/.config/yazi/plugins/

# Windows
mkdir %AppData%\yazi\config\plugins
xcopy archives.yazi %AppData%\yazi\config\plugins\archives.yazi /E
```

## Quick Setup

Add these keybindings to your `~/.config/yazi/keymap.toml`:

```toml
[mgr]
prepend_keymap = [
  { on = [ "c", "z" ], run = "plugin archives -- compress", desc = "📦 Compress selection" },
  { on = [ "c", "x" ], run = "plugin archives -- extract", desc = "📂 Extract archive" },
]
```

That's it! You're ready to go! 🎉

## Usage Guide

### Interactive Compression

1. Select files/folders in Yazi
2. Press `c` + `z`
3. Enter archive name (e.g., `backup.tar.gz`, `files.zip`)
4. Watch the magic happen! ✨

### Command Line Usage

#### Compress Files

```bash
# Interactive mode
:plugin archives -- compress

# Direct compression
:plugin archives -- compress backup.tar.gz
:plugin archives -- compress project.zip
:plugin archives -- compress data.7z
```

#### Extract Archives

```bash
# Extract to current directory
:plugin archives -- extract

# Extract to specific directory
:plugin archives -- extract ./extracted

# Extract with verbose output
:plugin archives -- extract -v
```

### Supported Workflows

- **Backup Creation**: Select multiple folders → `c+z` → `backup-$(date).tar.gz`
- **Project Archiving**: Select source code → `c+z` → `project-v1.0.zip`
- **Quick Extraction**: Navigate to archive → `c+x` → Done!
- **Batch Processing**: Works with multiple selected archives

## Tool Requirements

The plugin works with whatever you have installed! It intelligently detects and prioritizes the best available tools:

### Basic Tools (Usually Pre-installed)

- `tar`, `zip`, `unzip`, `gzip`, `bzip2`, `xz`

### Performance Tools (Recommended)

```bash
# Ubuntu/Debian
sudo apt install pigz pbzip2 lbzip2 pixz lz4 zstd p7zip-full

# macOS (Homebrew)
brew install pigz pbzip2 lbzip2 pixz lz4 zstd p7zip

# Arch Linux
sudo pacman -S pigz pbzip2 lbzip2 pixz lz4 zstd p7zip

# Fedora
sudo dnf install pigz pbzip2 lbzip2 pixz lz4 zstd p7zip
```

### Specialized Tools (Optional)

- `rar`, `unrar` - For RAR archives
- `zpaq` - For ZPAQ archives

## 📄 License

MIT - Feel free to use, modify, and distribute!
