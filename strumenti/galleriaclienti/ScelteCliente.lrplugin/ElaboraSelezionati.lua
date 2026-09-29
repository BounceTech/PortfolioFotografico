--[[
  ElaboraSelezionati.lua
  Applica il preset "Selezione base" e Auto Tone (Cmd+U) a tutte le foto
  attualmente selezionate in Lightroom. Utile per una prima passata veloce
  dopo la selezione manuale.
]]

local LrApplication       = import 'LrApplication'
local LrApplicationView   = import 'LrApplicationView'
local LrTasks             = import 'LrTasks'
local LrDialogs           = import 'LrDialogs'
local LrPathUtils         = import 'LrPathUtils'

local PRESET_NAME = 'Selezione base'

local function trovaPreset(name)
  for _, folder in ipairs(LrApplication.developPresetFolders()) do
    for _, preset in ipairs(folder:getDevelopPresets()) do
      if preset:getName() == name then return preset end
    end
  end
  return nil
end

LrTasks.startAsyncTask(function()
  local catalog = LrApplication.activeCatalog()
  local photos  = catalog:getTargetPhotos()

  if #photos == 0 then
    LrDialogs.message('Elabora selezionati',
      'Nessuna foto selezionata in Lightroom.\nSeleziona le foto da elaborare e rilancia.', 'warning')
    return
  end

  local ok = LrDialogs.confirm('Elabora selezionati',
    'Applico preset "' .. PRESET_NAME .. '" e Auto Tone a ' .. #photos .. ' foto selezionate.\nContinuo?',
    'Sì, elabora', 'Annulla')
  if ok ~= 'ok' then return end

  -- 1. Preset
  local preset = trovaPreset(PRESET_NAME)
  if not preset then
    LrDialogs.message('Preset non trovato',
      'Preset "' .. PRESET_NAME .. '" non trovato.\nCrealo in Develop → New Preset.', 'warning')
    return
  end
  catalog:withWriteAccessDo('Preset base', function()
    for _, photo in ipairs(photos) do
      photo:applyDevelopPreset(preset, catalog)
    end
  end)

  -- 2. Auto Tone (Cmd+U) foto per foto
  local prevModule = LrApplicationView.getCurrentModuleName()
  LrApplicationView.switchToModule('develop')
  LrTasks.sleep(0.8)

  for _, photo in ipairs(photos) do
    catalog:setSelectedPhotos(photo, { photo })
    LrTasks.sleep(0.8)
    LrTasks.execute("osascript -e 'tell application \"Adobe Lightroom Classic\" to activate' -e 'tell application \"System Events\" to keystroke \"u\" using {command down}'")
    LrTasks.sleep(0.4)
  end

  LrApplicationView.switchToModule(prevModule)

  LrDialogs.message('Elabora selezionati — fatto',
    #photos .. ' foto elaborate:\nPreset "' .. PRESET_NAME .. '" applicato\nAuto Tone applicato', 'info')
end)
