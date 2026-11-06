#!/usr/bin/env python3
"""Налаштовує config.json open.mp під UA RolePlay (зберігає решту стандартних параметрів)."""
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    c = json.load(f)

c["name"] = "UA RolePlay | Ukrainian RP"
c["language"] = "Ukrainian"
c["max_players"] = 100
c["enable_query"] = True
c.setdefault("pawn", {})
c["pawn"]["main_scripts"] = ["uarp 1"]
c["pawn"]["side_scripts"] = []
c.setdefault("rcon", {})
# Справжній пароль RCON вписується вже на комп'ютері власника, не в публічному репозиторії
c["rcon"]["password"] = "CHANGE_ME"
c.setdefault("network", {})
c["network"]["port"] = 7777

with open(path, "w", encoding="utf-8") as f:
    json.dump(c, f, ensure_ascii=False, indent=4)
print("config.json updated")
