-- ABH force OFF (SERVER) — запасной выключатель.
-- Применение: CE меню Table -> Show Cheat Table Lua Script -> вставить
-- этот файл -> Execute. Работает независимо от галочек в таблице:
-- находит гейт ABH по префиксу и возвращает заводские байты JE.
-- Нужен на случай, если крестик записи ABH - SERVER не снимается:
-- скрипт ищет запатченный гейт (E9) и чинит его в ванилу (0F 84 ...).
-- Байты ванилы зашиты под сборку server.dll 11470336 от 02.10.2026.

local srv = getAddress('server.dll')
local sz = getModuleSize('server.dll')
local l = AOBScan('F3 0F 11 40 48 A1 ?? ?? ?? ?? 83 78 14 01')
local fixed = 0
if l ~= nil then
  for i = 0, l.Count - 1 do
    local a = tonumber(l[i], 16)
    if a ~= nil and a >= srv and a < srv + sz then
      if readInteger(a + 14, 1, false) % 256 == 0xE9 then
        writeBytes(a + 14, 0x0F, 0x84, 0x39, 0x09, 0x00, 0x00)
        fixed = fixed + 1
      end
    end
  end
  l.destroy()
end
showMessage('repaired gates: ' .. tostring(fixed))
