--[[
  MatchUtils.lua — logica di ricerca foto condivisa tra ImportaScelte e Watcher.

  cercaFoto(catalog, names, isInScope)
    catalog   : LrApplication.activeCatalog()
    names     : lista di stringhe lowercase (nomi file senza estensione)
    isInScope : function(path) → true se la foto è nel lavoro giusto

  Ritorna: found[], ambigue[], assenti[]
    found   : LrPhoto taggabili (esistono nel catalogo E nel lavoro giusto)
    ambigue : nomi trovati nel catalogo ma SOLO in un altro lavoro (NON taggare)
    assenti : nomi non trovati nel catalogo
]]

local M = {}

function M.cercaFoto(catalog, names, isInScope)
  local nameSet = {}
  for _, n in ipairs(names) do nameSet[n] = true end

  local index = {}
  for _, photo in ipairs(catalog:getAllPhotos()) do
    local path = photo:getRawMetadata('path') or ''
    local base = (path:match('([^/]+)$') or ''):gsub('%.[%w]+$', ''):lower()
    if nameSet[base] then
      index[base] = index[base] or {}
      index[base][#index[base] + 1] = { photo = photo, path = path }
    end
  end

  local found, ambigue, assenti = {}, {}, {}
  for _, n in ipairs(names) do
    local cands = index[n]
    if not cands then
      assenti[#assenti + 1] = n
    else
      local pick
      for _, c in ipairs(cands) do
        if isInScope(c.path) then pick = c.photo; break end
      end
      if pick then
        found[#found + 1] = pick
      else
        ambigue[#ambigue + 1] = n  -- esiste nel catalogo ma solo in un altro lavoro
      end
    end
  end

  return found, ambigue, assenti
end

return M
