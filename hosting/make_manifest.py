#!/usr/bin/env python3
"""
Генерує manifest.json для лаунчера UA RolePlay.

Покладіть свої файли сервера (HUD, скіни, звуки, текстури) у папку  hosting/files/
і запустіть:
    python make_manifest.py

Скрипт порахує розмір і SHA-256 кожного файлу та запише manifest.json поруч.
Після цього завантажте news.json, manifest.json і папку files/ на свій хостинг
(туди, куди вказує CDN_URL у Config.kt).

Параметри (необов'язково):
    --version 5             версія збірки файлів (просто для себе)
    --launcher-version 2    мінімальна версія лаунчера; старіші попросять оновитися
    --launcher-url https://.../UARPLauncher.apk   звідки качати новий лаунчер
"""
import argparse
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FILES_DIR = os.path.join(HERE, "files")
OUT = os.path.join(HERE, "manifest.json")

# Файли GTA San Andreas не можна викладати: гра належить Rockstar.
FORBIDDEN = {"gta3.img", "gta_int.img", "gta_sa.exe", "libgtasa.so", "gta3.dir", "texdb"}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", type=int, default=1)
    ap.add_argument("--launcher-version", type=int, default=1)
    ap.add_argument("--launcher-url", default="")
    args = ap.parse_args()

    if not os.path.isdir(FILES_DIR):
        os.makedirs(FILES_DIR)
        print("Створено порожню папку files/. Покладіть туди файли сервера і запустіть ще раз.")

    files = []
    for root, _dirs, names in os.walk(FILES_DIR):
        for name in sorted(names):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, FILES_DIR).replace(os.sep, "/")
            if name.startswith("."):
                continue
            if any(part.lower() in FORBIDDEN for part in rel.split("/")):
                print(f"ПРОПУЩЕНО {rel}: це файл гри Rockstar, його не можна роздавати.")
                continue
            files.append({"path": rel, "size": os.path.getsize(full), "sha256": sha256(full)})
            print(f"+ {rel}")

    manifest = {
        "version": args.version,
        "launcher_version": args.launcher_version,
        "launcher_url": args.launcher_url,
        "files": sorted(files, key=lambda f: f["path"]),
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    total = sum(f["size"] for f in files)
    print(f"\nГотово: {len(files)} файл(ів), {total / 1024 / 1024:.1f} МБ -> manifest.json")


if __name__ == "__main__":
    sys.exit(main())
