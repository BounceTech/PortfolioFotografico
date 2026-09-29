--[[
  Watcher.lua — controlla in background il canale Telegram e applica le selezioni.
  Parte da solo all'avvio del plugin (LrInitPlugin in Info.lua).

  Messaggio atteso nel canale (lo manda la galleria):
    SELEZIONE|JOB=<lavoro>|NOME=<persona>|FOTO=<nome1 nome2 ...>|SECRET=<hmac16>

  Flusso automatico dopo la ricezione:
    1. Applica keyword  Scelte clienti › lavoro › persona
    2. Applica preset Develop fisso (PRESET_NAME) — denoise, lens, curve, ecc.
    3. Passa al modulo Develop, applica Auto Tone foto per foto, torna al modulo precedente
    4. Manda 2 notifiche Telegram: una per la selezione, una per l'elaborazione

  DEBUG: scrive un log in  ~/scelte_watcher.log
]]

local LrApplication     = import 'LrApplication'
local LrApplicationView = import 'LrApplicationView'
local LrDevelopController = import 'LrDevelopController'
local LrTasks           = import 'LrTasks'
local LrHttp            = import 'LrHttp'
local LrDialogs         = import 'LrDialogs'
local LrPrefs           = import 'LrPrefs'
local LrPathUtils       = import 'LrPathUtils'
local MatchUtils        = dofile(LrPathUtils.child(_PLUGIN.path, 'MatchUtils.lua'))

-- ===== CONFIG =====
local Segreti        = dofile(LrPathUtils.child(_PLUGIN.path, 'Segreti.lua'))  -- ignorato da git
local TELEGRAM_TOKEN = Segreti.TELEGRAM_TOKEN
local CHANNEL_ID     = Segreti.CHANNEL_ID      -- canale "Inbox Selezioni" — riceve i messaggi dalla galleria
local NOTIFY_ID      = Segreti.NOTIFY_ID       -- chat personale Mattia — riceve le notifiche di elaborazione
local MASTER_KEY     = Segreti.MASTER_KEY      -- deve combaciare con segreti.py
local PRESET_NAME    = 'Selezione base'         -- crea questo preset in LR una volta sola
                                                 -- (Develop → New Preset, includi denoise/lens/curva)
-- ===================

local POLL_SECONDS = 15
local ROOT         = 'Scelte clienti'
local BASE         = 'https://api.telegram.org/bot' .. TELEGRAM_TOKEN .. '/'

-- ---- log ----
local LOGPATH = LrPathUtils.child(LrPathUtils.getStandardFilePath('home'), 'scelte_watcher.log')
local function logmsg(s)
  pcall(function()
    local f = io.open(LOGPATH, 'a')
    if f then f:write(os.date('%H:%M:%S') .. '  ' .. tostring(s) .. '\n'); f:close() end
  end)
end

-- ---- URL encode (per testo Telegram) ----
local function urlEncode(s)
  return (s:gsub('([^%w%-_%.~])', function(c)
    return string.format('%%%02X', string.byte(c))
  end))
end

-- ---- invia messaggio nel canale Telegram (best-effort, non blocca) ----
-- NON mettere in pcall: LrHttp.get yielda e non può attraversare pcall (C function).
local function sendTelegram(msg)
  if NOTIFY_ID == '' then return end
  local url = BASE .. 'sendMessage?chat_id=' .. urlEncode(NOTIFY_ID)
              .. '&text=' .. urlEncode(msg)
  local body = LrHttp.get(url)
  if not body then
    logmsg('sendTelegram: nessuna risposta HTTP')
  else
    logmsg('sendTelegram: ok (' .. #body .. ' byte)')
  end
end

-- ---- HMAC-SHA256 via openssl CLI (stesso algoritmo di genera.py) ----
local function makeSecret(job)
  local cmd = "printf '%s' '" .. job .. "' | openssl dgst -sha256 -hmac '" .. MASTER_KEY .. "' 2>/dev/null | awk '{print $NF}'"
  local h = io.popen(cmd)
  local result = h and h:read('*l') or ''
  pcall(function() if h then h:close() end end)
  return result:sub(1, 16)
end

-- ---- mini decoder JSON ----
local function jsonDecode(str)
  local pos = 1
  local parseValue
  local function skipWs() pos = str:find('[^ \t\r\n]', pos) or (#str + 1) end
  local function parseString()
    pos = pos + 1
    local buf = {}
    while pos <= #str do
      local c = str:sub(pos, pos)
      if c == '"' then pos = pos + 1; return table.concat(buf)
      elseif c == '\\' then
        local n = str:sub(pos + 1, pos + 1)
        local map = { n = '\n', t = '\t', r = '\r', b = '\b', f = '\f', ['/'] = '/', ['\\'] = '\\', ['"'] = '"' }
        if map[n] then buf[#buf + 1] = map[n]
        elseif n == 'u' then
          local code = tonumber(str:sub(pos + 2, pos + 5), 16) or 0
          if code < 0x80 then buf[#buf + 1] = string.char(code)
          elseif code < 0x800 then buf[#buf + 1] = string.char(0xC0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
          else buf[#buf + 1] = string.char(0xE0 + math.floor(code / 0x1000), 0x80 + (math.floor(code / 0x40) % 0x40), 0x80 + (code % 0x40)) end
          pos = pos + 4
        else buf[#buf + 1] = n end
        pos = pos + 2
      else buf[#buf + 1] = c; pos = pos + 1 end
    end
    error('stringa non chiusa')
  end
  local function parseNumber()
    local s = pos
    while pos <= #str and str:sub(pos, pos):match('[%d%.eE%+%-]') do pos = pos + 1 end
    return tonumber(str:sub(s, pos - 1))
  end
  local function parseObject()
    pos = pos + 1; local obj = {}; skipWs()
    if str:sub(pos, pos) == '}' then pos = pos + 1; return obj end
    while true do
      skipWs(); local key = parseString()
      skipWs(); pos = pos + 1
      obj[key] = parseValue()
      skipWs(); local c = str:sub(pos, pos); pos = pos + 1
      if c == '}' then return obj end
    end
  end
  local function parseArray()
    pos = pos + 1; local arr = {}; skipWs()
    if str:sub(pos, pos) == ']' then pos = pos + 1; return arr end
    while true do
      arr[#arr + 1] = parseValue()
      skipWs(); local c = str:sub(pos, pos); pos = pos + 1
      if c == ']' then return arr end
    end
  end
  parseValue = function()
    skipWs(); local c = str:sub(pos, pos)
    if c == '{' then return parseObject()
    elseif c == '[' then return parseArray()
    elseif c == '"' then return parseString()
    elseif c == 't' then pos = pos + 4; return true
    elseif c == 'f' then pos = pos + 5; return false
    elseif c == 'n' then pos = pos + 4; return nil
    else return parseNumber() end
  end
  return parseValue()
end

-- ---- trova preset Develop per nome ----
local function trovaPreset(name)
  for _, folder in ipairs(LrApplication.developPresetFolders()) do
    for _, preset in ipairs(folder:getDevelopPresets()) do
      if preset:getName() == name then return preset end
    end
  end
  return nil
end

-- ---- applica preset fisso (denoise, lens, curva ecc.) ----
-- Silenziosa: non cambia modulo, non seleziona foto.
local function applicaPreset(catalog, photos)
  local preset = trovaPreset(PRESET_NAME)
  if not preset then
    logmsg('  preset "' .. PRESET_NAME .. '" non trovato — crealo in LR (Develop → New Preset)')
    return false
  end
  catalog:withWriteAccessDo('Preset base (auto)', function()
    for _, photo in ipairs(photos) do
      photo:applyDevelopPreset(preset, catalog)
    end
  end)
  logmsg('  preset "' .. PRESET_NAME .. '" applicato a ' .. #photos .. ' foto')
  return true
end

-- ---- applica Auto Tone in modulo Develop ----
-- Usa la scorciatoia Cmd+U via osascript: è l'unico modo affidabile per
-- triggerare Auto Tone da un plugin (l'SDK non espone questa funzione).
local function applicaAutoTone(catalog, photos)
  local prevModule = LrApplicationView.getCurrentModuleName()
  LrApplicationView.switchToModule('develop')
  LrTasks.sleep(0.8)

  local fatte = 0
  for _, photo in ipairs(photos) do
    catalog:setSelectedPhotos(photo, { photo })
    LrTasks.sleep(0.8)   -- attende che Develop carichi l'istogramma RAW
    -- Cmd+U = Auto Tone in Lightroom Develop
    LrTasks.execute("osascript -e 'tell application \"Adobe Lightroom Classic\" to activate' -e 'tell application \"System Events\" to keystroke \"u\" using {command down}'")
    LrTasks.sleep(0.4)   -- attende che LR applichi i valori
    fatte = fatte + 1
  end

  LrApplicationView.switchToModule(prevModule)
  logmsg('  Auto Tone applicato a ' .. fatte .. '/' .. #photos .. ' foto')
  return fatte
end

-- ---- applica keyword + preset + auto tone, poi notifica ----
local function applicaSelezione(catalog, job, persona, names)
  local found, ambigue, assenti = MatchUtils.cercaFoto(catalog, names,
    function(path) return path:find(job, 1, true) end)

  if #found > 0 then
    -- 1. Keyword
    catalog:withWriteAccessDo('Scelte (auto)', function()
      local rootKw = catalog:createKeyword(ROOT, {}, false, nil, true)
      local jobKw  = catalog:createKeyword(job, {}, false, rootKw, true)
      local pKw    = catalog:createKeyword(persona, {}, false, jobKw, true)
      for _, photo in ipairs(found) do photo:addKeyword(pKw) end
    end)
    logmsg('  keyword applicate')

    -- 2. Preset fisso + Auto Tone
    applicaPreset(catalog, found)
    local fatte = applicaAutoTone(catalog, found)

    -- 3. Notifica Telegram unica a elaborazione completata
    local notifica = '✅ ' .. persona .. ' — ' .. job .. '\n'
                   .. #found .. '/' .. #names .. ' foto elaborate'
    if fatte > 0 then notifica = notifica .. ', Auto Tone applicato' end
    if #ambigue > 0 then notifica = notifica .. '\n⚠ ' .. #ambigue .. ' ambigue (altro lavoro)' end
    if #assenti > 0 then notifica = notifica .. '\n⚠ ' .. #assenti .. ' non nel catalogo' end
    notifica = notifica .. '\nPuoi aprire Lightroom e iniziare a editare.'
    sendTelegram(notifica)
  end

  return #found, ambigue, assenti
end

local function pollOnce(prefs)
  local offset = prefs.tgOffset or 0
  prefs.lastPollAt = os.date('%Y-%m-%d %H:%M:%S')
  prefs.lastPollEpoch = os.time()
  -- LrHttp.get NON va mai messo dentro pcall: in Lightroom "yield" (la sospensione
  -- della chiamata di rete) non può attraversare un pcall, che è una funzione C.
  local body = LrHttp.get(BASE .. 'getUpdates?timeout=0&offset=' .. offset)
  if not body then
    logmsg('poll offset=' .. offset .. '  HTTP body=NIL (rete/SSL?)')
    prefs.lastErrorAt = prefs.lastPollAt
    prefs.lastErrorEpoch = prefs.lastPollEpoch
    prefs.lastErrorMsg = 'Nessuna risposta da Telegram (rete/SSL?)'
    return
  end
  logmsg('poll offset=' .. offset .. '  body=' .. #body .. ' byte')

  local ok, data = pcall(jsonDecode, body)
  if not ok or type(data) ~= 'table' or not data.result then
    logmsg('  parse fallito o senza result. inizio body: ' .. body:sub(1, 120))
    prefs.lastErrorAt = prefs.lastPollAt
    prefs.lastErrorEpoch = prefs.lastPollEpoch
    prefs.lastErrorMsg = 'Risposta Telegram non valida: ' .. body:sub(1, 150)
    return
  end
  logmsg('  update ricevuti: ' .. #data.result)

  local catalog = LrApplication.activeCatalog()
  local maxId = offset - 1
  for _, u in ipairs(data.result) do
    if u.update_id and u.update_id > maxId then maxId = u.update_id end
    local cp = u.message or u.channel_post
    if cp and cp.text then
      logmsg('  message chat=' .. tostring(cp.chat and cp.chat.id) .. ' text=' .. cp.text:sub(1, 60))
      if cp.text:find('^SELEZIONE|') then
        if CHANNEL_ID == '' or (cp.chat and tostring(cp.chat.id) == CHANNEL_ID) then
          local job     = cp.text:match('JOB=([^|]*)') or 'Senza nome'
          local persona = cp.text:match('NOME=([^|]*)') or 'Scelte'
          local secret  = cp.text:match('SECRET=([^|%s]*)') or ''
          local expected = makeSecret(job)
          if secret ~= expected then
            logmsg('  RIFIUTATO: SECRET non valido (ricevuto="' .. secret .. '", atteso="' .. expected .. '") job=' .. job)
            prefs.lastErrorAt    = prefs.lastPollAt
            prefs.lastErrorEpoch = prefs.lastPollEpoch
            prefs.lastErrorMsg   = 'Messaggio rifiutato: SECRET non valido per job=' .. job
          else
            local fotos = cp.text:match('FOTO=([^|]*)') or ''
            local names = {}
            for w in fotos:gmatch('%S+') do names[#names + 1] = w:lower() end
            logmsg('  SELEZIONE job=' .. job .. ' persona=' .. persona .. ' nfoto=' .. #names)
            if #names > 0 then
              local n, ambigue, assenti = applicaSelezione(catalog, job, persona, names)
              logmsg('  -> taggate ' .. n .. '/' .. #names ..
                     '  ambigue=' .. #ambigue .. '  assenti=' .. #assenti)
              local bezel = 'Selezione ' .. persona .. ': ' .. n .. '/' .. #names .. ' foto elaborate'
              if #ambigue > 0 then
                bezel = bezel .. '  ⚠ ' .. #ambigue .. ' ambigue'
                logmsg('  AMBIGUE: ' .. table.concat(ambigue, ', '))
              end
              if #assenti > 0 then
                logmsg('  ASSENTI: ' .. table.concat(assenti, ', '))
              end
              prefs.lastActionAt    = os.date('%Y-%m-%d %H:%M:%S')
              prefs.lastActionEpoch = os.time()
              prefs.lastActionMsg   = job .. ' › ' .. persona .. ': ' .. n .. '/' .. #names .. ' elaborate' ..
                                      (#ambigue > 0 and (', ' .. #ambigue .. ' ambigue') or '') ..
                                      (#assenti > 0 and (', ' .. #assenti .. ' assenti') or '')
              LrDialogs.showBezel(bezel)
            end
          end
        else
          logmsg('  ignorato: chat ' .. tostring(cp.chat and cp.chat.id) .. ' != CHANNEL_ID ' .. CHANNEL_ID)
        end
      end
    end
  end
  if maxId >= offset then prefs.tgOffset = maxId + 1 end
end

-- Avvio del watcher in background
LrTasks.startAsyncTask(function()
  logmsg('=== watcher: startAsyncTask partito ===')
  if TELEGRAM_TOKEN:find('INCOLLA') then logmsg('token non configurato, esco'); return end
  local prefs = LrPrefs.prefsForPlugin()

  if prefs.tgOffset == nil then
    local body = LrHttp.get(BASE .. 'getUpdates?timeout=0')   -- niente pcall, vedi nota sopra
    if not body then logmsg('chiamata iniziale: nessuna risposta (rete/SSL?)') end
    local maxId = 0
    if body then
      local ok, data = pcall(jsonDecode, body)
      if ok and type(data) == 'table' and data.result then
        for _, u in ipairs(data.result) do
          if u.update_id and u.update_id > maxId then maxId = u.update_id end
        end
      elseif not ok then
        logmsg('ERRORE parse JSON iniziale: ' .. tostring(data) .. ' | body=' .. body:sub(1,150))
      end
    end
    prefs.tgOffset = maxId + 1
  end
  logmsg('watcher avviato, offset iniziale=' .. tostring(prefs.tgOffset))
  LrDialogs.showBezel('Watcher selezioni avviato')
  prefs.startedAt = os.date('%Y-%m-%d %H:%M:%S')
  prefs.startedEpoch = os.time()

  prefs.gen = (prefs.gen or 0) + 1
  local myGen = prefs.gen

  -- Aspetta un momento: se c'è un doppio avvio (LrInitPlugin + click manuale),
  -- solo l'istanza con gen più alta sopravvive. Così mandiamo la notifica una volta sola.
  LrTasks.sleep(1)
  if prefs.gen == myGen then
    sendTelegram('🟢 Watcher attivo — ' .. prefs.startedAt .. '\nLightroom è aperto e pronto a ricevere selezioni.')
  end

  -- Ogni ciclo vive pochi secondi e si riprogramma da solo, invece di un unico
  -- task che dorme per sempre: un task "eterno" può essere abbandonato in
  -- silenzio da Lightroom dopo un po'. Tanti task brevi non hanno questo problema.
  local function ciclo()
    if prefs.gen ~= myGen then logmsg('watcher fermato (gen cambiata, myGen=' .. myGen .. ')'); return end
    pollOnce(prefs)   -- niente pcall qui: pollOnce chiama LrHttp.get, vedi nota sopra
    if prefs.gen ~= myGen then logmsg('watcher fermato (gen cambiata, myGen=' .. myGen .. ')'); return end
    LrTasks.startAsyncTask(function()
      LrTasks.sleep(POLL_SECONDS)
      ciclo()
    end)
  end
  ciclo()
end)
