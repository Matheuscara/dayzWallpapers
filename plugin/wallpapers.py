#!/usr/bin/env python3
"""Indexa imagens locais por pasta e escolhe a próxima sem executar comandos."""
import argparse
import json
import os
from pathlib import Path
import random

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".avif", ".bmp", ".jxl"}


def scan(directory, excluded=(), limit=10000):
    root = Path(directory).expanduser()
    if not root.is_absolute():
        raise ValueError("Escolha uma pasta com caminho absoluto.")
    root = root.resolve(strict=True)
    if not root.is_dir():
        raise ValueError("O caminho escolhido não é uma pasta.")
    images, seen, warnings = [], set(), []
    groups = {}

    def on_error(error):
        warnings.append(f"Pasta inacessível: {error.filename}")

    for folder, directories, files in os.walk(root, followlinks=False, onerror=on_error):
        directories[:] = sorted(name for name in directories if not name.startswith(".") and name not in excluded and not (Path(folder) / name).is_symlink())
        for name in sorted(files, key=str.casefold):
            path = Path(folder) / name
            if name.startswith(".") or path.suffix.lower() not in EXTENSIONS:
                continue
            try:
                actual = path.resolve(strict=True)
                if not actual.is_relative_to(root) or not actual.is_file() or actual in seen:
                    continue
                if any(part in excluded for part in actual.relative_to(root).parts[:-1]):
                    continue
            except (OSError, RuntimeError):
                continue
            seen.add(actual)
            category = actual.parent.relative_to(root).as_posix()
            groups[category] = groups.get(category, 0) + 1
            images.append({"path": str(actual), "url": actual.as_uri(), "name": actual.name, "category": category})
            if len(images) >= limit:
                warnings.append(f"Limite de {limit} imagens atingido; escolha uma pasta menor.")
                break
        if len(images) >= limit:
            break
    categories = [{"id": key, "name": "Arquivos soltos" if key == "." else key.replace("-", " "), "count": count}
                  for key, count in sorted(groups.items(), key=lambda item: item[0].casefold())]
    return {"version": 1, "root": str(root), "images": images, "categories": categories, "warnings": warnings, "error": ""}


def choose(images, category="", mode="random", current="", rng=None):
    if mode not in {"random", "sequential"}:
        raise ValueError("Ordem inválida.")
    pool = [image for image in images if not category or image["category"] == category]
    if not pool:
        return ""
    current = str(Path(current).expanduser().resolve()) if current else ""
    if mode == "sequential":
        index = next((i for i, image in enumerate(pool) if image["path"] == current), -1)
        return pool[(index + 1) % len(pool)]["path"]
    candidates = [image for image in pool if image["path"] != current] or pool
    return (rng or random.SystemRandom()).choice(candidates)["path"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True)
    parser.add_argument("--exclude", default="")
    parser.add_argument("--pick", action="store_true")
    parser.add_argument("--select", default="")
    parser.add_argument("--category", default="")
    parser.add_argument("--mode", choices=["random", "sequential"], default="random")
    parser.add_argument("--current", default="")
    args = parser.parse_args()
    try:
        result = scan(args.root, {name.strip() for name in args.exclude.split(",") if name.strip()})
        if args.select:
            requested = str(Path(args.select).resolve())
            result["choice"] = next((image["path"] for image in result["images"] if image["path"] == requested), "")
        elif args.pick:
            result["choice"] = choose(result["images"], args.category, args.mode, args.current)
    except (OSError, ValueError) as error:
        result = {"version": 1, "images": [], "categories": [], "warnings": [], "error": str(error)}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
