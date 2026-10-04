# -*- coding: utf-8 -*-
"""Проверка, что synergy_abh.CT подойдет к твоим server.dll/client.dll.

Запуск:  python check_abh_v2.py
Проверяет ТОЧНЫЕ AOB v2 (включая байты смещения):
  server: F3 0F 11 40 48 A1 ?? ?? ?? ?? 83 78 14 01 0F 84 39 09 00 00 8B 4E 04
  client: F3 0F 11 40 48 A1 ?? ?? ?? ?? 83 78 14 01 0F 84 A5 04 00 00 89 F1
Должно быть ровно по 1 совпадению. Иначе билд другой - v2 не включать.
Патч CE правит только ПАМЯТЬ, файлы на диске не трогает (этот скрипт всегда
покажет ванильные 0F 84 - так и должно быть).
"""
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
GAME = HERE.parent

def scan(path, aob_hex):
    data = pathlib.Path(path).read_bytes()
    rx = b''
    for tok in aob_hex.split():
        rx += b'.' if tok == '??' else bytes((int(tok, 16),))
    pat = re.compile(rx)
    return data, list(pat.finditer(data))

SRV = GAME / 'synergy' / 'bin' / 'server.dll'
CLI = GAME / 'synergy' / 'bin' / 'client.dll'

ok = True
d, ms = scan(SRV, 'F3 0F 11 40 48 A1 ?? ?? ?? ?? 83 78 14 01 0F 84 39 09 00 00 8B 4E 04')
print('server.dll: %d байт, AOB v2 совпадений: %d (нужно 1)' % (len(d), len(ms)))
for m in ms:
    rva = m.start() + 0xC00
    print('  server.dll+%X, байты гейта: %s' % (rva + 14, d[m.start()+14:m.start()+20].hex(' ')))
if len(ms) != 1:
    ok = False

d, ms = scan(CLI, 'F3 0F 11 40 48 A1 ?? ?? ?? ?? 83 78 14 01 0F 84 A5 04 00 00 89 F1')
print('client.dll: %d байт, AOB v2 совпадений: %d (нужно 1)' % (len(d), len(ms)))
for m in ms:
    rva = m.start() + 0xC00
    print('  client.dll+%X, байты гейта: %s' % (rva + 14, d[m.start()+14:m.start()+20].hex(' ')))
if len(ms) != 1:
    ok = False

print('OK: v2 включится.' if ok else 'ВНИМАНИЕ: билд другой, v2 НЕ включать - пришли этот вывод.')
sys.exit(0 if ok else 1)
