# -*- coding: utf-8 -*-
"""Сборка synergy_abh.CT с Lua-управляемыми записями (без registersymbol).

Каждая запись при клике заново ищет гейт в памяти: ENABLE ставит патч,
DISABLE возвращает ванилу. Никакого состояния между кликами -> залипать
нечему. Попутно чинится и старая боль: +E (hex!) вместо +14.
"""
import pathlib
import xml.dom.minidom

SRV_MOD = 'server.dll'
CLI_MOD = 'client.dll'
# Точные AOB ванилы (fail-closed: на чужом билде не найдётся -> отказ с окном)
SRV_EXACT = 'F3 0F 11 40 48 A1 ?? ?? ?? ?? 83 78 14 01 0F 84 39 09 00 00 8B 4E 04'
CLI_EXACT = 'F3 0F 11 40 48 A1 ?? ?? ?? ?? 83 78 14 01 0F 84 A5 04 00 00 89 F1'
# Префикс для поиска запатченного гейта (без опкода)
PREFIX = 'F3 0F 11 40 48 A1 ?? ?? ?? ?? 83 78 14 01'
SRV_ON = (0xE9, 0x3A, 0x09, 0x00, 0x00, 0x90)
SRV_OFF = (0x0F, 0x84, 0x39, 0x09, 0x00, 0x00)
CLI_ON = (0xE9, 0xA6, 0x04, 0x00, 0x00, 0x90)
CLI_OFF = (0x0F, 0x84, 0xA5, 0x04, 0x00, 0x00)
# Суффикс после гейта (цел, т.к. патч 6 в 6): проверка "это точно наш патч"
SRV_SUFFIX = (0x8B, 0x4E)
CLI_SUFFIX = (0x89, 0xF1)


def lua_bytes(tup):
    return ', '.join('0x%02X' % b for b in tup)


def enable_lua(mod, exact, onbytes, tag):
    return (
        'do\n'
        '  local base = getAddress(\'' + mod + '\')\n'
        '  local msg = \'\'\n'
        '  if base == nil or base == 0 then\n'
        '    msg = \'' + mod + ' not found - attach to synergy.exe first\'\n'
        '  else\n'
        '    local size = getModuleSize(\'' + mod + '\')\n'
        '    local l = AOBScan(\'' + exact + '\')\n'
        '    local found = nil\n'
        '    if l ~= nil then\n'
        '      for i = 0, l.Count - 1 do\n'
        '        local a = tonumber(l[i], 16)\n'
        '        if a ~= nil and a >= base and a < base + size then\n'
        '          if found ~= nil then found = -1 break end\n'
        '          found = a\n'
        '        end\n'
        '      end\n'
        '      l.destroy()\n'
        '    end\n'
        '    if found == nil then\n'
        '      msg = \'gate not found - wrong game build? run check_abh.py\'\n'
        '    elseif found == -1 then\n'
        '      msg = \'ambiguous: several matches, NOT patched (report this)\'\n'
        '    else\n'
        '      writeBytes(found + 14, ' + lua_bytes(onbytes) + ')\n'
        '      print(string.format(\'ABH ' + tag + ' enabled at %X\', found + 14))\n'
        '    end\n'
        '  end\n'
        '  if msg ~= \'\' then showMessage(\'ABH ' + tag + ' enable: \' .. msg) end\n'
        'end\n'
    )


def disable_lua(mod, offbytes, suffix, tag):
    return (
        'do\n'
        '  local base = getAddress(\'' + mod + '\')\n'
        '  local msg = \'\'\n'
        '  if base == nil or base == 0 then\n'
        '    msg = \'' + mod + ' not found - attach to synergy.exe first\'\n'
        '  else\n'
        '    local size = getModuleSize(\'' + mod + '\')\n'
        '    local l = AOBScan(\'' + PREFIX + '\')\n'
        '    local fixed = 0\n'
        '    if l ~= nil then\n'
        '      for i = 0, l.Count - 1 do\n'
        '        local a = tonumber(l[i], 16)\n'
        '        if a ~= nil and a >= base and a < base + size then\n'
        '          local op = readInteger(a + 14, 1, false) % 256\n'
        '          if op == 0xE9 then\n'
        '            local s0 = readInteger(a + 20, 1, false) % 256\n'
        '            local s1 = readInteger(a + 21, 1, false) % 256\n'
        '            if s0 == 0x' + '%02X' % suffix[0] + ' and s1 == 0x' + '%02X' % suffix[1] + ' then\n'
        '              writeBytes(a + 14, ' + lua_bytes(offbytes) + ')\n'
        '              fixed = fixed + 1\n'
        '            end\n'
        '          end\n'
        '        end\n'
        '      end\n'
        '      l.destroy()\n'
        '    end\n'
        '    if fixed == 0 then\n'
        '      msg = \'no patched gate found (already vanilla?)\'\n'
        '    else\n'
        '      print(\'ABH ' + tag + ' disabled, gates restored: \' .. tostring(fixed))\n'
        '    end\n'
        '  end\n'
        '  if msg ~= \'\' then showMessage(\'ABH ' + tag + ' disable: \' .. msg) end\n'
        'end\n'
    )


def entry(eid, desc, mod, exact, onbytes, offbytes, suffix, tag):
    body = (
        '[ENABLE]\n'
        '{$lua}\n' + enable_lua(mod, exact, onbytes, tag) + '{$asm}\n'
        '[DISABLE]\n'
        '{$lua}\n' + disable_lua(mod, offbytes, suffix, tag) + '{$asm}\n'
    )
    esc = body.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    return (
        '    <CheatEntry>\n'
        '      <ID>' + str(eid) + '</ID>\n'
        '      <Description>"' + desc + '"</Description>\n'
        '      <VariableType>Auto Assembler Script</VariableType>\n'
        '      <AssemblerScript>' + esc + '</AssemblerScript>\n'
        '    </CheatEntry>\n'
    )


doc = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<CheatTable CheatEngineTableVersion="42">\n'
    '  <CheatEntries>\n'
    + entry(1, 'ABH - SERVER (вкл/выкл)', SRV_MOD, SRV_EXACT, SRV_ON, SRV_OFF, SRV_SUFFIX, 'SERVER')
    + entry(2, 'ABH - CLIENT predict (вкл/выкл)', CLI_MOD, CLI_EXACT, CLI_ON, CLI_OFF, CLI_SUFFIX, 'CLIENT')
    + '  </CheatEntries>\n'
    '  <UserdefinedSymbols/>\n'
    '</CheatTable>\n'
)

out = pathlib.Path('ABH_Synergy/synergy_abh.CT')
out.write_text(doc, encoding='utf-8')
xml.dom.minidom.parse(str(out))
print('lua CT valid, bytes:', len(doc.encode('utf-8')))
