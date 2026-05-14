# Portable Dev Setup

Portable Linux development environment across:

- Fedora
- Arch Linux
- openSUSE Tumbleweed
- Debian-based distros including Ubuntu and PikaOS

This repo packages your shell, terminal, editor, and CLI setup into a portable dotfiles-style repository for web, mobile, and DevOps work. It avoids machine-specific state, keeps desktop-specific customization minimal, and is structured for direct GitHub publishing.

## Features

- Shared shell environment for `bash` and `zsh`
- Role-based bootstrap for base, web, mobile, and DevOps tooling
- `mise` runtime bootstrap for Node.js, Python, Java, Go, Rust, Bun, and Deno
- Flutter SDK and Android SDK command-line bootstrap for mobile work
- Upstream installer bootstrap for cross-distro DevOps tools like `terragrunt`, `stern`, `trivy`, `sops`, `cosign`, `kind`, `k9s`, `kubectx`, `kubens`, and `minikube`
- IDE management delegated to `jetbrains-toolbox`
- Starship prompt, tmux workflow config, and Atuin defaults
- VS Code extensions, settings, and keybindings
- CLI tooling for web, cloud, containers, Kubernetes, Terraform, and general development
- Kitty, Alacritty, btop, GTK overrides, Git defaults, and MIME defaults
- KDE color scheme asset
- Optional GNOME defaults
- Optional KDE Plasma defaults

## Repo layout

```text
config/home/         portable dotfiles linked into $HOME
config/templates/    rendered configs with per-user paths
config/vscode/       VS Code extension list
lib/                 package maps, shared shell helpers, and vendor installers
scripts/             installers and desktop apply scripts
tests/               verification tests for package resolution and detection
assets/kde/          KDE config assets
```

## Quick Start

```bash
git clone <your-repo-url>
cd dev-setup-portable
chmod +x scripts/*.sh
./scripts/install.sh
```

Default role installed by `./scripts/install.sh` is `base` only. Additional roles must be opted into explicitly:

```bash
./scripts/install.sh                          # base only
./scripts/install.sh --roles base,web,devops
./scripts/install.sh --roles base,mobile --optional
./scripts/install.sh --no-vendor
```

Optional desktop profile:

```bash
./scripts/install.sh --desktop gnome
./scripts/install.sh --desktop kde
```

If `--desktop` is not provided, the installer will try to detect GNOME or KDE automatically from the current session and apply the matching profile.

### Non-Interactive Install

You can run the installer without prompting for input by using `--non-interactive`. You can optionally supply your Git user info:

```bash
export GH_TOKEN="ghp_xxx" # GitHub token is required in non-interactive mode unless --no-github is passed
./scripts/install.sh --non-interactive --git-name "Jane Doe" --git-email "jane@example.com"
```

Other available flags:
- `--optional`: attempt to install GUI packages like VS Code, Chrome, Podman Desktop, and JetBrains Toolbox.
- `--no-vendor`: skip vendor bootstraps (like `mise`, Flutter SDK, and Android SDK).
- `--no-git`: skip git user configuration.
- `--no-github`: skip GitHub authentication and SSH key setup.
- `--skip-shell-change`: do not attempt to change the default shell to `zsh`.

## Install Behavior

- Detects distro package manager automatically
- Detects GNOME or KDE automatically when possible
- Installs selected role groups with distro-specific package names
- Installs `base` role only by default; additional roles must be specified with `--roles`
- Required package installation failures will halt the setup to prevent broken environments.
- Can attempt optional GUI packages like VS Code, Chrome, Podman Desktop, and JetBrains Toolbox with `--optional`. (GUI app installation failures will simply show a warning and continue.)
- Links the portable config into your home directory
- Renders path-aware config templates for VS Code
- Bootstraps `mise`, Flutter, Android SDK components, JetBrains Toolbox, and upstream DevOps binaries unless `--no-vendor` is used; vendor tools are fetched at their latest GitHub release automatically
- Automatically authenticates with GitHub CLI and creates an SSH key (unless `--no-github` is passed). Fails the install if auth fails.
- Detects installed browser (Chrome → Chromium → Firefox → Brave) and writes MIME handler entries dynamically
- Backs up conflicting existing files into `~/.local/share/dev-setup-portable/backups/<timestamp>/`
- Writes a full install log to `~/.local/share/dev-setup-portable/install-<timestamp>.log`
- Applies optional GNOME or KDE defaults only when requested

## Included Config

- Shell: `.zshrc`, `.bashrc`, `.profile`, shared shell helpers
- Runtime manager: `mise` config for Node.js, Python, Java, Go, Rust, Bun, and Deno
- Prompt and terminal: Starship, Kitty, Alacritty
- CLI UX: tmux (with sessionizer, cheatsheet, and clipboard-bridge scripts), btop, Atuin
- Editor: VS Code extensions, settings, keybindings, JetBrains Toolbox
- Desktop defaults: GTK overrides, MIME defaults, GNOME/KDE apply scripts
- Theme assets: KDE color scheme

## Supported desktops

### GNOME

Applies a small set of safe defaults with `gsettings` when available:

- dark style preference
- favorite apps
- monospace font preference

Also tries to install a minimal dev-oriented GNOME extension set when local GNOME extension tooling is available:

- AppIndicator and KStatusNotifierItem Support
- Clipboard Indicator
- Tiling Assistant
- Caffeine

### KDE Plasma

Installs a matching color scheme and basic terminal/browser defaults where possible.

## Notes

- Some packages are not available under the exact same name on every distro. The installer maps names per distro and skips unsupported packages when necessary.
- Some tools still depend on upstream downloads on specific distros. The script handles `mise`, Flutter, Android SDK components, JetBrains Toolbox, and several DevOps tools directly, but some GUI apps may still be skipped when the package is unavailable.
- `docker.service` is enabled only if Docker is installed and systemd is available.
- `podman.socket` is enabled for the user session when available.
- Android SDK installation accepts licenses automatically and installs `platform-tools`, `platforms;android-35`, `build-tools;35.0.0`, and `emulator`.
- Upstream-installed binaries are placed in `~/.local/bin`.
- Git configuration: when running with `--non-interactive`, Git configuration is skipped (with a warning) if `--git-name` and `--git-email` are not explicitly provided.

## Publishing Checklist

1. Update the repo URL in the quick start block.
2. Review `scripts/install.sh` package selections for your preferred toolset.
3. Add screenshots if you want to show the terminal/editor setup.
4. Push to GitHub and add a short repo description.

## License

This repo is licensed under the MIT License.
