--[[
  Scelte cliente - plugin Lightroom Classic (gratuito, fatto in casa)
  by Mattia Buoli

  Trasforma il messaggio di selezione del cliente in una Collection
  pronta da editare, in un solo click. Niente terminale, niente .txt.
]]

return {
  LrSdkVersion = 11.0,
  LrSdkMinimumVersion = 6.0,
  LrToolkitIdentifier = 'it.mattiabuoli.sceltecliente',
  LrPluginName = 'Scelte cliente',
  LrLibraryMenuItems = {
    {
      title = 'Selezione cliente',
      file = 'ImportaScelte.lua',
    },
    {
      title = 'Elabora selezionati',
      file = 'ElaboraSelezionati.lua',
    },
  },
  VERSION = { major = 1, minor = 0, revision = 0 },
}
