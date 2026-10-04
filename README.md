# SynergyABH — pure HL2 Accelerated Back Hop for Synergy

Pure Half-Life 2 single-player Accelerated Back Hop restored for Synergy
listen servers. No strafe boost — just the original jump bonus math.

- [How to use](#how-to-use)
- [How it works](#how-it-works)
- [Files](#files)
- [Warnings](#warnings)
- [Русская версия](#русская-версия)

> Tested only in **Synergy** (build 02.10.2026, ServerVersion 4300).
> Not guaranteed to work in other games or builds — run `check_abh.py` first.

## How to use

1. Launch Synergy → Create Game (listen server).
2. *(Optional)* Copy `abh_binds.cfg` to `synergy/cfg/` and run `exec abh_binds`
   in the console — binds jump to the mouse wheel and shows speed
   (`cl_showpos 1`). You can set your own binds instead.
3. In Cheat Engine: attach to `synergy.exe` → open `synergy_abh.CT`
   (if you had an older copy open, close it and open the file again —
   CE caches the loaded table).
4. Enable both entries (`ABH - SERVER` + *(Optional)* `ABH - CLIENT predict`).
   SERVER alone is usually enough for the host; CLIENT keeps prediction
   (and `cl_showpos`) honest.
5. Do ABH :)
   Don't know how to ABH? Watch this tutorial:
   https://youtu.be/58tuz5wunU8?si=yCmcgcWv1tQ_w8LM
   Speed should grow exponentially: ~350 → ~490 → ~770 → 1300+.
6. Disabling the entries restores vanilla Synergy physics, no restart needed.
   If the `ABH - SERVER` checkbox ever refuses to uncheck, run
   `abh_force_off.lua` (Table → Show Cheat Table Lua Script → Execute).

## How it works

**1. Where ABH speed comes from.** On jump, the engine adds a bonus to
horizontal velocity (simplified from the HL2 source):

```c
// We give a certain percentage of the current forward movement
// as a bonus to the jump speed.
float flSpeedBoostPerc = (!sprinting && !ducked) ? 0.5f : 0.1f;
float flSpeedAddition  = fabs(mv->m_flForwardMove * flSpeedBoostPerc);
float flMaxSpeed       = mv->m_flMaxSpeed + mv->m_flMaxSpeed * flSpeedBoostPerc;
float flNewSpeed       = flSpeedAddition + mv->m_vecVelocity.Length2D();

// If we're over the maximum, we want to only boost
// as much as will get us to the goal speed
if (flNewSpeed > flMaxSpeed)
    flSpeedAddition -= flNewSpeed - flMaxSpeed;

// Moving backwards turns the "penalty" into acceleration:
if (mv->m_flForwardMove < 0.0f)
    flSpeedAddition *= -1.0f;

VectorAdd(vecForward * flSpeedAddition, mv->m_vecVelocity, mv->m_vecVelocity);
```

The bug: the cap is computed from your speed but applied along your view
direction. Hop flying backwards (turned 180°) and the game "slows you down"
into going faster. Net formula: `new = old*2 − limit` (~209 crouched —
hence exponential growth).

**2. Why Synergy has no ABH.** The whole bonus runs only if:

```asm
mov eax,[gpGlobals]
cmp dword ptr [eax+14],01   ; maxClients == 1 ?
je  <ABH block>             ; yes = single-player -> run it
```

On a listen server `maxClients > 1` even when you're alone, so the block is
skipped. The block itself is still in the DLLs (verified by disassembly in
both modules: `fabs` via `andps` mask, `Length2D` via `sqrt`, cap via
`cmpltss`, sign flip via `xorps` mask, constants `0.1f`, `0.5f` and the
`{0.1, 0.5}` table indexed by `!ducked` — exactly the single-player formula).

**3. What the script does.** Flips that `JE` into a `JMP` to the same target
(1 opcode byte + NOP, displacement preserved):

| Module | Gate | Was | Patched to |
|---|---|---|---|
| `server.dll` | `+2891C` | `0F 84 …` = `je 2925B` | `E9 … 90` = `jmp 2925B` + `nop` |
| `client.dll` | `+88319` | `0F 84 …` = `je 887C4` | `E9 … 90` = `jmp 887C4` + `nop` |

The server entry enables the physics itself; the client entry fixes movement
prediction (without it `cl_showpos` lies and rubber-banding is possible).
Displacement bytes are pinned to one specific build — after a game update the
AOB simply won't match and the script refuses to enable instead of patching
foreign code.

## Files

| File | What it is |
|---|---|
| `synergy_abh.CT` | Cheat Engine table: `ABH - SERVER` + `ABH - CLIENT predict`, toggle live |
| `abh_binds.cfg` | *(Optional)* wheel-jump binds + `cl_showpos 1` |
| `check_abh.py` | Build compatibility check (`python check_abh.py` must print `1 and 1`) |
| `abh_diag_v1_1.lua` / `.CT` | Read-only signature diagnostics in live memory (for porting to new builds) |
| `abh_force_off.lua` | Backup SERVER off-switch (run via Table Lua Script if the checkbox sticks) |
| `build_abh.py` | Regenerates `synergy_abh.CT` from sources (`python build_abh.py`) |

## Warnings

- **Your own listen server only.** On other people's servers the physics runs
  on their `server.dll` — the patch does nothing there. Never join
  VAC-secured servers with Cheat Engine open — ban risk. Close CE and restart
  the game before going online.
- Patches live only in memory — re-enable the entries after each restart.
- After a Synergy update, run `check_abh.py` first.
- Research project (reverse engineering + restoring cut single-player
  mechanics). Not for cheating against real players.

## History

The first attempt targeted the wrong `maxClients` gate (a single-player
debug block — there are 71 such checks in `server.dll`) and was revoked.
The real ABH block was found via its twin in `client.dll` (exactly one such
gate there) and confirmed byte-for-byte in `server.dll`. Lesson learned: in
Cheat Engine all numbers are hexadecimal (`+E`, not `+14`), and AOB
displacements are pinned so the script fails closed instead of patching
foreign code.

## License

MIT — see [LICENSE](LICENSE).

---

## Русская версия

- [Использование](#использование)
- [Принцип работы](#принцип-работы)
- [Файлы](#файлы)
- [Предупреждения](#предупреждения)

> Проверено только в **Synergy** (сборка 02.10.2026, ServerVersion 4300).
> В других играх и сборках работа не гарантируется — сначала `check_abh.py`.

### Использование

1. Запусти Synergy → Create Game (listen server).
2. *(Опционально)* Скопируй `abh_binds.cfg` в `synergy/cfg/` и выполни
   `exec abh_binds` — прыжок на колесо + показ скорости (`cl_showpos 1`).
   Можно настроить свои бинды.
3. В Cheat Engine: attach к `synergy.exe` → открыть `synergy_abh.CT`
   (если была открыта старая копия — закрой и открой файл заново,
   CE кэширует загруженное).
4. Включить обе записи (`ABH - SERVER` + *(Опционально)* `ABH - CLIENT predict`).
   Хосту обычно хватает SERVER; CLIENT нужен для честного предсказания
   и `cl_showpos`.
5. Наслаждайся ABH :)
   Не умеешь ABH? Смотри обучение:
   https://youtu.be/58tuz5wunU8?si=yCmcgcWv1tQ_w8LM
   Скорость растёт экспоненциально: ~350 → ~490 → ~770 → 1300+.
6. Выключение записей возвращает ванильную физику, рестарт не нужен.
   Если галочка `ABH - SERVER` вдруг не снимается — выполни
   `abh_force_off.lua` (Table → Show Cheat Table Lua Script → Execute).

### Принцип работы

**1. Откуда берётся скорость в ABH.** При прыжке движок начисляет бонус
к горизонтальной скорости (упрощённо, по исходникам HL2):

```c
// We give a certain percentage of the current forward movement
// as a bonus to the jump speed.
float flSpeedBoostPerc = (!sprinting && !ducked) ? 0.5f : 0.1f;
float flSpeedAddition  = fabs(mv->m_flForwardMove * flSpeedBoostPerc);
float flMaxSpeed       = mv->m_flMaxSpeed + mv->m_flMaxSpeed * flSpeedBoostPerc;
float flNewSpeed       = flSpeedAddition + mv->m_vecVelocity.Length2D();

// If we're over the maximum, we want to only boost
// as much as will get us to the goal speed
if (flNewSpeed > flMaxSpeed)
    flSpeedAddition -= flNewSpeed - flMaxSpeed;

// Двигаемся назад — "штраф" превращается в разгон:
if (mv->m_flForwardMove < 0.0f)
    flSpeedAddition *= -1.0f;

VectorAdd(vecForward * flSpeedAddition, mv->m_vecVelocity, mv->m_vecVelocity);
```

Фишка бага: кап считается от скорости, а применяется вдоль взгляда.
Прыгаешь спиной вперёд (разворот на 180°) — игра пытается тебя «затормозить»,
а по факту разгоняет. Итоговая формула: `новая = старая*2 − лимит`
(в присяде лимит ~209 — отсюда экспонента).

**2. Почему в Synergy ABH нет.** Весь бонус выполняется только если:

```asm
mov eax,[gpGlobals]
cmp dword ptr [eax+14],01   ; maxClients == 1 ?
je  <ABH-блок>              ; да = синглплеер -> выполнить
```

На listen-сервере `maxClients > 1` даже когда ты один — блок пропускается.
Сам блок в DLL на месте (проверено дизассемблированием обоих модулей).

**3. Что делает скрипт.** Меняет `JE` на `JMP` с тем же таргетом
(1 байт опкода + NOP, смещение сохраняется):

| Модуль | Гейт | Было | Стало |
|---|---|---|---|
| `server.dll` | `+2891C` | `0F 84 …` = `je 2925B` | `E9 … 90` = `jmp 2925B` + `nop` |
| `client.dll` | `+88319` | `0F 84 …` = `je 887C4` | `E9 … 90` = `jmp 887C4` + `nop` |

Серверная запись включает саму физику, клиентская — предсказание движения.
Байты смещения зашиты точно под конкретную сборку: после обновления игры
AOB просто не найдётся и скрипт не включится — вместо порчи чужого кода.

### Файлы

| Файл | Что это |
|---|---|
| `synergy_abh.CT` | Cheat Engine-таблица: `ABH - SERVER` + `ABH - CLIENT predict`, вкл/выкл на ходу |
| `abh_binds.cfg` | *(Опционально)* бинды прыжка на колесо + `cl_showpos 1` |
| `check_abh.py` | Проверка совместимости (`python check_abh.py` → нужно `1 и 1`) |
| `abh_diag_v1_1.lua` / `.CT` | Read-only диагностика сигнатур в живой памяти (для портирования на новые билды) |
| `abh_force_off.lua` | Запасной выключатель SERVER (выполнить через Table Lua Script, если галочка не снимается) |
| `build_abh.py` | Пересборка `synergy_abh.CT` из исходников (`python build_abh.py`) |

### Предупреждения

- **Только свой listen server.** На чужих серверах физику считает чужой
  `server.dll` — патч там не сработает. Не заходи с открытым CE на
  VAC-защищённые серверы — риск бана. Перед выходом в интернет закрой CE
  и перезапусти игру.
- Патчи живут только в памяти — после рестарта игры включай записи заново.
- После обновления Synergy сначала прогони `check_abh.py`.
- Проект в исследовательских целях. Не для читерства против живых игроков.

### Лицензия

MIT — см. [LICENSE](LICENSE).
