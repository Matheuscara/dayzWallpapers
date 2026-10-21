#!/usr/bin/env python3
"""Instala Dayz Wallpapers no usuário e mantém a dependência Python no Nix store."""
import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import shutil
import subprocess
import time


def install(source, config_home, state_home, *, replace=False, dry_run=False):
    source = source.resolve(strict=True)
    if not (source / "plugin.json").is_file():
        raise ValueError("Fonte sem plugin.json")
    target = config_home / "DankMaterialShell/plugins/DayzWallpapers"
    exists = target.exists() or target.is_symlink()
    matching = target.is_symlink() and target.resolve() == source
    if exists and not matching and not replace:
        raise FileExistsError(f"{target} já existe. Use --replace para guardar backup e substituir.")
    print(f"{'Prévia' if dry_run else 'Instalar'}: {target} -> {source}")
    if dry_run:
        return target
    if str(source).startswith("/nix/store/"):
        state = state_home / "dayzWallpapers"
        state.mkdir(parents=True, exist_ok=True)
        subprocess.run(["nix-store", "--add-root", str(state / "current"),
                        "--indirect", "--realise", str(source)], check=True,
                       stdout=subprocess.DEVNULL)
    if matching:
        return target
    if exists:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        backup = config_home / "DankMaterialShell/backups" / f"dayz-wallpapers-{stamp}"
        backup.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if target.is_symlink():
            if target.exists():
                shutil.copytree(target.resolve(), backup, symlinks=True)
            else:
                backup.symlink_to(os.readlink(target))
            target.unlink()
        else:
            shutil.move(str(target), str(backup))
        print(f"Backup: {backup}")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.symlink_to(source)
    return target


def enable():
    if not shutil.which("dms"):
        print("DMS não encontrado. Requer DankMaterialShell 1.4.6+ instalado.")
        return
    for attempt in range(5):
        try:
            result = subprocess.run(["dms", "ipc", "call", "plugins", "enable", "dayzWallpapers"],
                                    capture_output=True, text=True, timeout=5)
        except subprocess.TimeoutExpired:
            break
        if result.returncode == 0 and "PLUGIN_NOT_FOUND" not in result.stdout + result.stderr:
            print("Habilitado no DMS. Abrir: dms ipc call dayzWallpapers toggle")
            return
        if attempt < 4:
            time.sleep(0.5)
    print("Instalado. Reinicie o DMS quando conveniente e habilite Dayz Wallpapers em Plugins.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1] / "plugin")
    parser.add_argument("--config-home", type=Path, default=Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")))
    parser.add_argument("--state-home", type=Path, default=Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")))
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-enable", action="store_true")
    args = parser.parse_args()
    try:
        install(args.source.expanduser(), args.config_home.expanduser(), args.state_home.expanduser(),
                replace=args.replace, dry_run=args.dry_run)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"{error}\n")
    if not args.dry_run and not args.no_enable:
        enable()


if __name__ == "__main__":
    main()
