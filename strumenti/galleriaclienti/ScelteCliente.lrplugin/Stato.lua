--[[
  Stato.lua — mostra a colpo d'occhio se il watcher delle selezioni sta
  funzionando: da quanto è attivo, l'ultimo controllo, l'ultima selezione
  applicata e l'ultimo eventuale errore.
]]

local LrDialogs = import 'LrDialogs'
local LrPrefs   = import 'LrPrefs'

local POLL_SECONDS = 15   -- deve combaciare con Watcher.lua

local function fa(epoch)
  if not epoch then return nil end
  local s = os.time() - epoch
  if s < 0 then s = 0 end
  if s < 60 then return s .. ' secondi fa' end
  if s < 3600 then return math.floor(s / 60) .. ' minuti fa' end
  return math.floor(s / 3600) .. ' ore fa'
end

local prefs = LrPrefs.prefsForPlugin()
local lines = {}

if not prefs.startedAt then
  table.insert(lines, '⚠ Il watcher non risulta mai avviato in questa sessione di Lightroom.')
  table.insert(lines, 'Vai su Library > Plug-in Extras > "Avvia watcher selezioni (auto)".')
else
  table.insert(lines, 'Avviato: ' .. prefs.startedAt .. ' (' .. (fa(prefs.startedEpoch) or '?') .. ')')

  if prefs.lastPollAt then
    local secondsAgo = prefs.lastPollEpoch and (os.time() - prefs.lastPollEpoch) or nil
    local vivo = secondsAgo ~= nil and secondsAgo < (POLL_SECONDS * 3)
    table.insert(lines, '')
    table.insert(lines, (vivo and '✓ ATTIVO' or '⚠ NESSUN CONTROLLO RECENTE — potrebbe essersi fermato') )
    table.insert(lines, 'Ultimo controllo: ' .. prefs.lastPollAt .. ' (' .. (fa(prefs.lastPollEpoch) or '?') .. ')')
    if not vivo then
      table.insert(lines, 'Se sono passati più di 1-2 minuti, riavvialo da Plug-in Extras.')
    end
  else
    table.insert(lines, '')
    table.insert(lines, '⚠ Nessun controllo registrato ancora.')
  end

  table.insert(lines, '')
  if prefs.lastActionAt then
    table.insert(lines, 'Ultima selezione applicata (' .. (fa(prefs.lastActionEpoch) or '?') .. '):')
    table.insert(lines, '  ' .. (prefs.lastActionMsg or '?'))
  else
    table.insert(lines, 'Nessuna selezione applicata ancora in questa sessione.')
  end

  if prefs.lastErrorAt then
    table.insert(lines, '')
    table.insert(lines, '⚠ Ultimo errore (' .. (fa(prefs.lastErrorEpoch) or '?') .. '):')
    table.insert(lines, '  ' .. (prefs.lastErrorMsg or '?'))
  end
end

LrDialogs.message('Stato watcher selezioni', table.concat(lines, '\n'), 'info')
