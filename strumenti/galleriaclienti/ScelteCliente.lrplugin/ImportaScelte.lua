--[[
  ImportaScelte.lua
  Legge il messaggio del cliente dagli appunti, trova le foto nel catalogo
  (preferendo la cartella del lavoro) e applica una keyword gerarchica
  "Scelte clienti > lavoro > persona". Niente collezioni, niente bandierina.
]]

local LrApplication       = import 'LrApplication'
local LrApplicationView   = import 'LrApplicationView'
local LrDevelopController = import 'LrDevelopController'
local LrTasks             = import 'LrTasks'
local LrPathUtils         = import 'LrPathUtils'
local LrDialogs           = import 'LrDialogs'
local LrFunctionContext   = import 'LrFunctionContext'
local LrView              = import 'LrView'
local LrBinding           = import 'LrBinding'
local LrProgressScope     = import 'LrProgressScope'
local LrFileUtils         = import 'LrFileUtils'
local MatchUtils          = dofile(LrPathUtils.child(_PLUGIN.path, 'MatchUtils.lua'))

local ROOT        = 'Scelte clienti'
local PRESET_NAME = 'Selezione base'

local function trovaPreset(name)
  for _, folder in ipairs(LrApplication.developPresetFolders()) do
    for _, preset in ipairs(folder:getDevelopPresets()) do
      if preset:getName() == name then return preset end
    end
  end
  return nil
end

local function applicaPreset(catalog, photos)
  local preset = trovaPreset(PRESET_NAME)
  if not preset then
    LrDialogs.message('Preset non trovato',
      'Preset "' .. PRESET_NAME .. '" non trovato. Crealo in Develop → New Preset.', 'warning')
    return false
  end
  catalog:withWriteAccessDo('Preset base', function()
    for _, photo in ipairs(photos) do
      photo:applyDevelopPreset(preset, catalog)
    end
  end)
  return true
end

local function applicaAutoTone(catalog, photos)
  local prevModule = LrApplicationView.getCurrentModuleName()
  LrApplicationView.switchToModule('develop')
  LrTasks.sleep(0.8)
  local fatte = 0
  for _, photo in ipairs(photos) do
    catalog:setSelectedPhotos(photo, { photo })
    LrTasks.sleep(0.8)
    LrTasks.execute("osascript -e 'tell application \"Adobe Lightroom Classic\" to activate' -e 'tell application \"System Events\" to keystroke \"u\" using {command down}'")
    LrTasks.sleep(0.4)
    fatte = fatte + 1
  end
  LrApplicationView.switchToModule(prevModule)
  return fatte
end

-- Legge il testo attualmente copiato negli appunti (macOS, pbpaste)
local function leggiAppunti()
  local tmp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'scelte_clip.txt')
  LrTasks.execute('/usr/bin/pbpaste > "' .. tmp .. '"')
  local f = io.open(tmp, 'r')
  if not f then return '' end
  local txt = f:read('*a') or ''
  f:close()
  return txt
end

local function contaCifre(s)
  local _, n = s:gsub('%d', '')
  return n
end

-- Estrae TUTTI i nomi-file dal testo (ovunque siano: a capo, in fila, con virgole).
-- Un nome valido inizia con lettera/underscore (esclude la data del titolo) e ha >=3 cifre.
local function estraiNomi(text)
  local ordered, seen = {}, {}
  for token in text:gmatch('[%w%._%-]+') do
    local base = token:match('^(.-)%.[%w]+$') or token   -- toglie l'estensione se presente
    base = base:lower()
    if base ~= '' and not seen[base]
       and base:sub(1, 1):match('[%a_]')
       and contaCifre(base) >= 3 then
      seen[base] = true
      ordered[#ordered + 1] = base
    end
  end
  return ordered
end

-- Chiede il nome di chi ha fatto la selezione (diventa l'ultimo livello della keyword)
local function chiediNome(defaultName)
  local nome
  LrFunctionContext.callWithContext('chiediNome', function(context)
    local props = LrBinding.makePropertyTable(context)
    props.nome = defaultName or ''
    local f = LrView.osFactory()
    local contents = f:column{
      spacing = f:control_spacing(),
      f:static_text{ title = 'Nome di chi ha selezionato (es. Mario):' },
      f:edit_field{ value = LrView.bind{ key = 'nome', object = props }, width_in_chars = 22 },
    }
    local res = LrDialogs.presentModalDialog{
      title = 'Scelte cliente',
      contents = contents,
    }
    if res == 'ok' then nome = props.nome end
  end)
  return nome
end

LrTasks.startAsyncTask(function()
  local catalog = LrApplication.activeCatalog()

  local text = leggiAppunti()
  if text:gsub('%s', '') == '' then
    LrDialogs.message('Scelte cliente',
      'Gli appunti sono vuoti. Copia prima il messaggio del cliente, poi rilancia il plugin.', 'warning')
    return
  end

  local names = estraiNomi(text)
  if #names == 0 then
    LrDialogs.message('Scelte cliente',
      'Non ho riconosciuto nomi file nel messaggio copiato.\n\nControlla di aver copiato la lista delle foto.', 'warning')
    return
  end

  -- Cartella del lavoro attualmente aperta (indipendente da cosa è selezionato).
  local folderPath = nil
  for _, src in ipairs(catalog:getActiveSources()) do
    local ok, p = pcall(function() return src:getPath() end)
    if ok and type(p) == 'string' and p ~= '' then folderPath = p; break end
  end
  local function dentroCartella(path)
    if not folderPath then return true end
    if path:sub(1, #folderPath) ~= folderPath then return false end
    local nextc = path:sub(#folderPath + 1, #folderPath + 1)
    return nextc == '' or nextc == '/'
  end

  local nameSet = {}
  for _, n in ipairs(names) do nameSet[n] = true end

  local progress = LrProgressScope({ title = 'Scelte cliente: cerco le foto…' })
  local found, fuori, missing = MatchUtils.cercaFoto(catalog, names, dentroCartella)
  progress:done()

  if #found == 0 then
    local dove = folderPath and ('nella cartella:\n' .. folderPath) or 'nel catalogo'
    local extra = ''
    if #fuori > 0 then
      extra = '\n\n⚠ ' .. #fuori .. ' esistono nel catalogo ma in un\'ALTRA cartella: ' .. table.concat(fuori, ', ') ..
              '\nApri la cartella giusta nel pannello Folders e rilancia.'
    end
    LrDialogs.message('Scelte cliente',
      'Nessuna delle ' .. #names .. ' foto è stata trovata ' .. dove .. '.' .. extra .. '\n\n' ..
      'Controlla che le foto siano importate in Lightroom e che i nomi combacino.', 'warning')
    return
  end

  -- Nome del lavoro = prima riga utile del messaggio (se non è una foto).
  local setName = nil
  for line in (text .. '\n'):gmatch('(.-)\n') do
    local t = line:gsub('^%s+', ''):gsub('%s+$', '')
    if t ~= '' then setName = t; break end
  end
  if setName then
    local hbase = (setName:match('^([%w%._%-]+)') or '')
    hbase = (hbase:match('^(.-)%.[%w]+$') or hbase):lower()
    if nameSet[hbase] then setName = nil end
  end
  if not setName or setName == '' then setName = 'Senza nome' end

  local persona = chiediNome('Scelte')
  if persona == nil then return end                       -- annullato
  persona = (persona:gsub('^%s+', ''):gsub('%s+$', ''))
  if persona == '' then persona = 'Scelte' end

  catalog:withWriteAccessDo('Scelte cliente', function()
    -- Keyword:  ROOT  ›  lavoro  ›  persona  (unica per lavoro+persona)
    local rootKw   = catalog:createKeyword(ROOT, {}, false, nil, true)
    local jobKw    = catalog:createKeyword(setName, {}, false, rootKw, true)
    local personKw = catalog:createKeyword(persona, {}, false, jobKw, true)
    for _, photo in ipairs(found) do
      photo:addKeyword(personKw)
    end
  end)

  applicaPreset(catalog, found)
  local fatte = applicaAutoTone(catalog, found)

  catalog:setSelectedPhotos(found[1], found)

  local msg = #found .. ' foto su ' .. #names ..
              ' taggate con keyword "' .. ROOT .. ' › ' .. setName .. ' › ' .. persona .. '".' ..
              '\nPreset applicato. Auto Tone: ' .. fatte .. '/' .. #found .. ' foto.'
  if #fuori > 0 then
    msg = msg .. '\n\n⚠ ' .. #fuori .. ' esistono nel catalogo ma in una cartella di un ALTRO lavoro: ' ..
          table.concat(fuori, ', ') ..
          '\nNON taggate (per non rischiare di scegliere la foto sbagliata). Verifica a mano se serve.'
  end
  if #missing > 0 then
    -- Controllo il disco nella cartella DOVE STANNO le foto trovate (certo, non dipende dalla vista).
    local refFolder = nil
    do
      local p = found[1]:getRawMetadata('path')
      if p then refFolder = LrPathUtils.parent(p) end
    end
    local diskBase = nil
    if refFolder then
      diskBase = {}
      for filePath in LrFileUtils.files(refFolder) do
        local b = (LrPathUtils.leafName(filePath):gsub('%.[%w]+$', '')):lower()
        diskBase[b] = true
      end
    end
    local suDisco, assenti = {}, {}
    for _, n in ipairs(missing) do
      if diskBase and diskBase[n] then suDisco[#suDisco + 1] = n
      else assenti[#assenti + 1] = n end
    end
    if refFolder then msg = msg .. '\n\nCartella controllata:\n' .. refFolder end
    if #suDisco > 0 then
      msg = msg .. '\n\n' .. #suDisco .. ' sono in cartella ma NON importate in Lightroom:\n' ..
            table.concat(suDisco, ', ') ..
            '\n→ Tasto destro sulla cartella › "Synchronize Folder…", poi rilancia.'
    end
    if #assenti > 0 then
      msg = msg .. '\n\n' .. #assenti .. ' originale assente in questa cartella (scartate dopo la galleria?):\n' ..
            table.concat(assenti, ', ')
    end
  end
  LrDialogs.message('Scelte cliente — fatto', msg, 'info')
end)
