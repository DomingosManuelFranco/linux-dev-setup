#!/usr/bin/env bash

ROLLBACK_ASSETS_DIR="$REPO_ROOT/assets/rollback"

# Check whether the running system meets the prerequisites for the rollback
# system: Arch Linux, btrfs root on subvolume @, and systemd-boot.
# Returns 0 if all prerequisites are met, 1 otherwise. Logs the reason on
# failure.
rollback_prerequisites_met() {
  local distro fstype subvol

  distro="$(detect_distro 2>/dev/null || true)"
  if [[ "$distro" != "arch" ]]; then
    log "Rollback system is Arch-only; skipping (detected: ${distro:-unknown})"
    return 1
  fi

  if ! fstype="$(findmnt -no FSTYPE / 2>/dev/null)"; then
    warn "Could not determine root filesystem type; skipping rollback setup"
    return 1
  fi
  if [[ "$fstype" != "btrfs" ]]; then
    log "Root filesystem is not btrfs ($fstype); skipping rollback setup"
    return 1
  fi

  if ! findmnt -no OPTIONS / 2>/dev/null | grep -q 'subvol=/@'; then
    log "Root is not on subvol=/@; skipping rollback setup"
    return 1
  fi

  if ! have bootctl; then
    warn "bootctl (systemd-boot) not found; skipping rollback setup"
    return 1
  fi

  if [[ ! -d /boot/EFI/Linux ]]; then
    warn "/boot/EFI/Linux not found (is /boot the ESP?); skipping rollback setup"
    return 1
  fi

  if [[ ! -f /etc/kernel/cmdline ]]; then
    warn "/etc/kernel/cmdline not found (needed to build UKIs); skipping rollback setup"
    return 1
  fi

  return 0
}

# Install the rollback packages (snap-pac, snapper, btrfs-progs) on Arch.
# Uses pacman directly since these are Arch-specific and not part of the
# generic package_group/map_package flow.
rollback_install_packages() {
  local -a needed=()
  local pkg

  for pkg in snapper btrfs-progs snap-pac; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
      needed+=("$pkg")
    fi
  done

  if [[ ${#needed[@]} -gt 0 ]]; then
    log "Installing rollback packages: ${needed[*]}"
    sudo pacman -S --needed --noconfirm "${needed[@]}" >/dev/null 2>&1 \
      || { record_setup_failure "rollback-packages (failed to install: ${needed[*]})"; return 1; }
  fi
}

# Install the bootable-UKI engine, arch-rollback script, pacman hook, and boot
# systemd service from the repo's assets/rollback/ directory.
rollback_install_scripts() {
  local assets="$ROLLBACK_ASSETS_DIR"

  if [[ ! -d "$assets" ]]; then
    record_setup_failure "rollback-assets (directory $assets not found)"
    return 1
  fi

  sudo install -Dm755 "$assets/snapper-bootable-uki" \
    /usr/local/bin/snapper-bootable-uki \
    || { record_setup_failure "rollback-snapper-bootable-uki"; return 1; }

  sudo install -Dm755 "$assets/arch-rollback" \
    /usr/local/bin/arch-rollback \
    || { record_setup_failure "rollback-arch-rollback"; return 1; }

  sudo install -Dm644 "$assets/zz-snap-pac-uki-pre.hook" \
    /etc/pacman.d/hooks/zz-snap-pac-uki-pre.hook \
    || { record_setup_failure "rollback-pacman-hook"; return 1; }

  sudo install -Dm644 "$assets/snapper-bootable-uki-boot.service" \
    /etc/systemd/system/snapper-bootable-uki-boot.service \
    || { record_setup_failure "rollback-boot-service"; return 1; }
}

# Enable snapper timers and the boot UKI service.
rollback_enable_timers() {
  sudo systemctl enable --now snapper-timeline.timer >/dev/null 2>&1 \
    || warn "Could not enable snapper-timeline.timer"
  sudo systemctl enable --now snapper-cleanup.timer >/dev/null 2>&1 \
    || warn "Could not enable snapper-cleanup.timer"
  sudo systemctl enable --now snapper-boot.timer >/dev/null 2>&1 \
    || warn "Could not enable snapper-boot.timer"
  sudo systemctl enable snapper-bootable-uki-boot.service >/dev/null 2>&1 \
    || warn "Could not enable snapper-bootable-uki-boot.service"
}

# Parse snapshot numbers from snapper list output, handling Unicode box-drawing
# separators. Prints newest snapshot number, or empty if none.
rollback_newest_snapshot() {
  snapper -c root list 2>/dev/null \
    | sed 's/│/|/g' \
    | awk -F'|' 'NR>2 {
        n=$1; gsub(/[[:space:]]/,"",n);
        if (n ~ /^[0-9]+$/ && n+0 > 0) print n+0
      }' | sort -n | tail -1
}

# Create a baseline snapshot if none exist, then build the first bootable UKI.
# Returns 1 (and records a failure) if the UKI build fails — the system is left
# unchanged otherwise.
rollback_create_baseline_and_uki() {
  local newest

  newest="$(rollback_newest_snapshot)"

  if [[ -z "$newest" ]]; then
    log "No snapper snapshots yet; creating a baseline snapshot"
    if ! snapper -c root create --description "rollback system baseline (installed $(date +%F))" 2>/dev/null; then
      record_setup_failure "rollback-baseline-snapshot (snapper create failed)"
      return 1
    fi
    newest="$(rollback_newest_snapshot)"
  fi

  if [[ -z "$newest" ]]; then
    record_setup_failure "rollback-baseline (no snapshot after create)"
    return 1
  fi

  log "Newest snapshot: #$newest — building bootable UKI (~30s)..."
  if sudo /usr/local/bin/snapper-bootable-uki init 2>&1 | sed 's/^/    /'; then
    log "Bootable UKI built successfully"
  else
    record_setup_failure "rollback-uki-build (mkinitcpio failed; system is unchanged)"
    return 1
  fi
}

# Main entry point: set up the full rollback system.
# Skips gracefully if prerequisites are not met (non-Arch, non-btrfs, etc.).
# Records failures via record_setup_failure so they appear in the install
# summary without halting the entire install.
setup_rollback_system() {
  if [[ "${SETUP_ROLLBACK:-1}" -ne 1 ]]; then
    log "Rollback system setup skipped (--no-rollback)"
    return 0
  fi

  if ! rollback_prerequisites_met; then
    return 0
  fi

  log "Setting up btrfs rollback system (snap-pac + bootable UKI snapshots)"

  rollback_install_packages || return 0
  rollback_install_scripts || return 0
  rollback_enable_timers
  rollback_create_baseline_and_uki || return 0

  log "Rollback system ready: bootable snapshots will appear in the systemd-boot menu"
  log "Recover with: reboot -> pick snapshot entry -> sudo arch-rollback N -> reboot"
}
