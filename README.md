# Portable Dev Setup

Portable Linux development environment for GNOME and KDE Plasma across:

- Fedora
- Arch Linux
- openSUSE Tumbleweed
- Ubuntu
- PikaOS

This repo packages your shell, terminal, editor, CLI, and theme setup into a portable dotfiles-style repository. It avoids machine-specific state, keeps desktop integration optional, and is structured for direct GitHub publishing.

## Features

- Shared shell environment for `bash` and `zsh`
- Starship prompt, tmux workflow config, and Atuin defaults
- VS Code extensions, settings, and keybindings
- CLI tooling for web, cloud, containers, Kubernetes, Terraform, and general development
- Kitty, Alacritty, btop, GTK overrides, Git defaults, and MIME defaults
- Portable theme assets for DankMaterialShell and KDE
- Optional GNOME defaults
- Optional KDE Plasma defaults

## Repo layout

```text
config/home/         portable dotfiles linked into $HOME
config/templates/    rendered configs with per-user paths
config/vscode/       VS Code extension list
lib/                 package maps and shared shell helpers
scripts/             installers and desktop apply scripts
assets/kde/          KDE config assets
```

## Quick Start

```bash
git clone <your-repo-url>
cd dev-setup-portable
chmod +x scripts/*.sh
./scripts/install.sh
```

Optional desktop profile:

```bash
./scripts/install.sh --desktop gnome
./scripts/install.sh --desktop kde
```

## Install Behavior

- Detects distro package manager automatically
- Installs a conservative base package set with distro-specific package names
- Can also attempt optional cloud, container, Kubernetes, editor, and browser packages with `--optional`
- Links the portable config into your home directory
- Renders path-aware config templates for VS Code and DankMaterialShell
- Backs up conflicting existing files into `~/.local/share/dev-setup-portable/backups/<timestamp>/`
- Applies optional GNOME or KDE defaults only when requested

## Included Config

- Shell: `.zshrc`, `.bashrc`, `.profile`, shared shell helpers
- Prompt and terminal: Starship, Kitty, Alacritty
- CLI UX: tmux, btop, Atuin
- Editor: VS Code extensions, settings, keybindings
- Desktop defaults: GTK overrides, MIME defaults, GNOME/KDE apply scripts
- Theme assets: DankMaterialShell theme, KDE color scheme

## Supported desktops

### GNOME

Applies a small set of safe defaults with `gsettings` when available:

- dark style preference
- favorite apps
- monospace font preference

### KDE Plasma

Installs a matching color scheme and basic terminal/browser defaults where possible.

## Notes

- Some packages are not available under the exact same name on every distro. The installer maps names per distro and skips unsupported optional packages.
- GUI application installation is intentionally conservative. Browsers, VS Code variants, Docker Desktop, and Google Cloud CLI may still require vendor repos or manual install depending on the distro.
- `docker.service` is enabled only if Docker is installed and systemd is available.
- `podman.socket` is enabled for the user session when available.

## Publishing Checklist

1. Update the repo URL in the quick start block.
2. Review `scripts/install.sh` package selections for your preferred toolset.
3. Add screenshots if you want to show the theme.
4. Push to GitHub and add a short repo description.

## License

Add your preferred license before publishing.
