-- ============================================================
-- ABH diag v1.2 -- ТОЛЬКО ЧТЕНИЕ, память не меняет.
-- Как запускать:
--   1. Прицепи CE к synergy.exe (кнопка с мигающим компьютером).
--   2. Открой эту таблицу через File -> Open (на вопрос про Lua ответь Yes/Да).
--   3. Результат покажется окном и скопируется в буфер обмена.
-- Если CE спросил про скрипт ДО attach'а: сделай attach, закрой и открой таблицу снова.
-- Вручную: CE меню Table -> Show Cheat Table Lua Script -> вставить abh_diag_v1_1.lua -> Execute.
-- ВАЖНО: все ABH-записи должны быть
-- ВЫКЛЮЧЕНА (крестик снят), иначе пункт [1] покажет 0x84 и картина смажется.
-- ============================================================

function diagMain()
  local rep = {}
  local function add(s) rep[#rep+1] = s end

  add('ABH diag v1.1 (read-only)')

  local pid = getOpenedProcessID()
  if pid == 0 then
    showMessage('ABH diag v1.1:\n\nСначала attach CE к synergy.exe, затем перезагрузи таблицу (File -> Open).')
    return
  end
  -- имя процесса: только best-effort, в старых CE этой функции нет
  local pname = 'pid=' .. tostring(pid)
  if getProcessnameFromProcessID ~= nil then
    local ok, nm = pcall(getProcessnameFromProcessID, pid)
    if ok and nm ~= nil then pname = tostring(nm) .. ' ' .. pname end
  end
  add('process: ' .. pname)

  local srvBase = getAddress('server.dll')
  local cliBase = getAddress('client.dll')
  if srvBase == nil or srvBase == 0 then
    showMessage('ABH diag v1.1:\n\nserver.dll не найден в процессе. Ты точно прицеплен к synergy.exe (а не к srcds/launcher)?')
    return
  end
  local srvSize = getModuleSize('server.dll')
  local cliSize = getModuleSize('client.dll')
  add(string.format('server.dll base=%X size=%X', srvBase, srvSize))
  if cliBase ~= nil and cliBase ~= 0 then
    add(string.format('client.dll base=%X size=%X', cliBase, cliSize))
  else
    add('client.dll не найден (норма для выделенного сервера)')
  end

  local function inMod(a, base, size)
    return a ~= nil and a >= base and a < (base + size)
  end

  -- [1] v1-гейт: должен быть ровно 1, байт+5: 0x85 ванила / 0x84 патч-v1-активен
  do
    local l = AOBScan('83 78 14 01 0F 85 ?? ?? ?? ?? 8B 5D 0C')
    if l == nil then
      add('[1] v1gate AOB: scan error (nil)')
    else
      local n = l.Count
      add('[1] v1gate AOB: всего совпадений в процессе: ' .. tostring(n) .. ' (ожидается 1)')
      for i = 0, n - 1 do
        local a = tonumber(l[i], 16)
        if inMod(a, srvBase, srvSize) then
          local op = (readInteger(a + 5, 1, false) % 256)
          local st
          if op == 0x84 then st = '0x84 (ВНИМАНИЕ: v1-патч сейчас АКТИВЕН, выключи его)'
          elseif op == 0x85 then st = '0x85 (ванила, v1 выключен - правильно)'
          else st = string.format('неизвестный 0x%X', op) end
          add(string.format('    server.dll+%X : байт+5 = %s', a - srvBase, st))
        else
          add(string.format('    ВНЕ server.dll: %X (странно, сообщи)', a))
        end
      end
      l.destroy()
    end
  end

  -- [2] все проверки maxClients [eax+14],1 (файл: server 67 / client 11)
  do
    local l = AOBScan('83 78 14 01')
    if l == nil then
      add('[2] cmp14: scan error (nil)')
    else
      local nS, nC = 0, 0
      local nT = l.Count
      for i = 0, nT - 1 do
        local a = tonumber(l[i], 16)
        if inMod(a, srvBase, srvSize) then nS = nS + 1
        elseif cliBase ~= nil and cliBase ~= 0 and inMod(a, cliBase, cliSize) then nC = nC + 1 end
      end
      add(string.format('[2] cmp[maxClients]: всего=%d server=%d client=%d (файл: 67/11)', nT, nS, nC))
      l.destroy()
    end
  end

  -- [3] velocity-site (цепочка addss/movss +0x40/+0x44, файл: server 1)
  do
    local l = AOBScan('F3 0F 58 4B 40 F3 0F 11 4B 40 F3 0F 58 53 44')
    if l == nil then
      add('[3] velsite: scan error (nil)')
    else
      add('[3] velsite: всего=' .. tostring(l.Count) .. ' (ожидается 1)')
      for i = 0, l.Count - 1 do
        local a = tonumber(l[i], 16)
        if inMod(a, srvBase, srvSize) then
          add(string.format('    server.dll+%X', a - srvBase))
        else
          add(string.format('    ВНЕ server.dll: %X (сообщи)', a))
        end
      end
      l.destroy()
    end
  end

  -- [4] JE-гейты maxClients (файл: server 25 / client 1); первые 8 server + все client
  do
    local l = AOBScan('A1 ?? ?? ?? ?? 83 78 14 01 0F 84')
    if l == nil then
      add('[4] je_gate: scan error (nil)')
    else
      local shown, nS, nC = 0, 0, 0
      for i = 0, l.Count - 1 do
        local a = tonumber(l[i], 16)
        if inMod(a, srvBase, srvSize) then
          nS = nS + 1
          if shown < 8 then
            add(string.format('    server.dll+%X', a - srvBase))
            shown = shown + 1
          end
        elseif cliBase ~= nil and cliBase ~= 0 and inMod(a, cliBase, cliSize) then
          nC = nC + 1
          add(string.format('    client.dll+%X', a - cliBase))
        end
      end
      add(string.format('[4] je_gate: всего=%d (server=%d client=%d; файл: 25/1)', l.Count, nS, nC))
      l.destroy()
    end
  end

  -- [5] v2-SERVER гейт в ПАМЯТИ (точный AOB). 0F 84 39.. = ванила, E9 3A .. 90 = v2 включён
  do
    local l = AOBScan('F3 0F 11 40 48 A1 ?? ?? ?? ?? 83 78 14 01 0F 84 39 09 00 00 8B 4E 04')
    if l == nil then
      add('[5] v2server: scan error (nil)')
    else
      add('[5] v2server AOB: всего=' .. tostring(l.Count) .. ' (ожидается 1)')
      for i = 0, l.Count - 1 do
        local a = tonumber(l[i], 16)
        if inMod(a, srvBase, srvSize) then
          local b0 = (readInteger(a + 14, 1, false) % 256)
          local st = (b0 == 0xE9) and 'E9 (v2-SERVER ВКЛЮЧЁН)' or ((b0 == 0x0F) and '0F 84 (ванила, v2-SERVER выключен)' or string.format('странный 0x%X', b0))
          add(string.format('    server.dll+%X : %s', a - srvBase, st))
        else
          add(string.format('    ВНЕ server.dll: %X (сообщи)', a))
        end
      end
      l.destroy()
    end
  end

  -- [6] v2-CLIENT гейт в ПАМЯТИ. 0F 84 A5.. = ванила, E9 A6 .. 90 = v2 включён
  do
    local l = AOBScan('F3 0F 11 40 48 A1 ?? ?? ?? ?? 83 78 14 01 0F 84 A5 04 00 00 89 F1')
    if l == nil then
      add('[6] v2client: scan error (nil)')
    else
      add('[6] v2client AOB: всего=' .. tostring(l.Count) .. ' (ожидается 1)')
      for i = 0, l.Count - 1 do
        local a = tonumber(l[i], 16)
        if cliBase ~= nil and cliBase ~= 0 and inMod(a, cliBase, cliSize) then
          local b0 = (readInteger(a + 14, 1, false) % 256)
          local st = (b0 == 0xE9) and 'E9 (v2-CLIENT ВКЛЮЧЁН)' or ((b0 == 0x0F) and '0F 84 (ванила, v2-CLIENT выключен)' or string.format('странный 0x%X', b0))
          add(string.format('    client.dll+%X : %s', a - cliBase, st))
        else
          add(string.format('    ВНЕ client.dll: %X (сообщи)', a))
        end
      end
      l.destroy()
    end
  end

  if getCEVersion ~= nil then
    local ok, v = pcall(getCEVersion)
    if ok and v ~= nil then add('CE: ' .. tostring(v)) end
  end
  local out = table.concat(rep, '\n')
  print(out)
  if writeToClipboard ~= nil then pcall(writeToClipboard, out) end
  showMessage(out .. '\n\n(если буфер обмена пуст — скопируй текст из этого окна вручную)')
end

diagMain()
