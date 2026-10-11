/**
 * Pulizia attività — quando elimini un lavoro dal DB "Lavori", le sue attività
 * (DB "Attività clienti", relazione "Servizio") finiscono anche loro nel cestino di Notion.
 * Se ripristini il lavoro dal cestino, tornano anche le attività.
 *
 * Gira da solo ogni 15 minuti (attivatore "pulisciAttivita", basato sul tempo).
 * Memoria nelle Proprietà script:
 *   att:<lavoro>        attività collegate al lavoro, viste all'ultimo giro
 *   cestinate:<lavoro>  attività spostate nel cestino insieme al lavoro (per ripristinarle)
 * Serve perché, una volta cestinato il lavoro, Notion può togliere la relazione dalle attività.
 */

var NOTION_DB_ATTIVITA = '35e937f0-1525-8088-838f-c0ebe9cb1cca';   // DB Attività clienti (non cambiare)
var REL_SERVIZIO       = 'Servizio';

function pulisciAttivita() {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(1000)) return;   // un giro alla volta
  try {
    var vivi = idPagine_(NOTION_DB_LAVORI, null);

    // Attività attuali → lavori a cui sono collegate
    var ora = {}, attivitaVive = {};
    idPagine_(NOTION_DB_ATTIVITA, function (p) {
      attivitaVive[p.id] = true;
      var rel = p.properties[REL_SERVIZIO];
      ((rel && rel.relation) || []).forEach(function (r) { (ora[r.id] = ora[r.id] || []).push(p.id); });
    });

    var mem = PropertiesService.getScriptProperties(), tutte = mem.getProperties(), lavori = {};
    Object.keys(tutte).forEach(function (k) { var m = k.match(/^(att|cestinate):(.+)$/); if (m) lavori[m[2]] = true; });
    Object.keys(ora).forEach(function (l) { lavori[l] = true; });

    // Attività che restano legate ad almeno un lavoro vivo: non si toccano mai
    var protette = {};
    Object.keys(ora).forEach(function (l) { if (vivi[l]) ora[l].forEach(function (a) { protette[a] = true; }); });

    var log = [];
    Object.keys(lavori).forEach(function (l) {
      var prima = JSON.parse(tutte['att:' + l] || '[]'), cestinate = JSON.parse(tutte['cestinate:' + l] || '[]');
      if (vivi[l]) {
        if (cestinate.length) {   // lavoro ripristinato: tornano anche le attività
          cestinate.forEach(function (a) { try { notion_('patch', '/pages/' + a, { archived: false }); } catch (err) {} });
          mem.deleteProperty('cestinate:' + l);
          log.push('ripristinate ' + cestinate.length + ' attività di ' + l);
        }
        if (ora[l]) mem.setProperty('att:' + l, JSON.stringify(ora[l])); else mem.deleteProperty('att:' + l);
        return;
      }
      var stato = statoPagina_(l);
      if (stato === 'viva') return;   // non è nel DB Lavori ma esiste: non è un lavoro cancellato
      if (stato === 'sparita') {      // eliminata per sempre dal cestino: dimentico
        mem.deleteProperty('att:' + l); mem.deleteProperty('cestinate:' + l);
        return;
      }
      var daCestinare = unici_(prima.concat(ora[l] || [])).filter(function (a) { return attivitaVive[a] && !protette[a]; });
      daCestinare.forEach(function (a) { notion_('patch', '/pages/' + a, { archived: true }); });
      if (daCestinare.length) {
        mem.setProperty('cestinate:' + l, JSON.stringify(unici_(cestinate.concat(daCestinare))));
        log.push('cestinate ' + daCestinare.length + ' attività del lavoro ' + l);
      }
      mem.deleteProperty('att:' + l);
    });
    if (log.length) Logger.log(log.join('\n'));
  } finally {
    lock.releaseLock();
  }
}

// Id delle pagine (non cestinate) di un DB; se c'è, ogni pagina passa anche da fn
function idPagine_(db, fn) {
  var ids = {}, cursor = null;
  do {
    var corpo = { page_size: 100 };
    if (cursor) corpo.start_cursor = cursor;
    var r = notion_('post', '/databases/' + db + '/query', corpo);
    r.results.forEach(function (p) { ids[p.id] = true; if (fn) fn(p); });
    cursor = r.has_more ? r.next_cursor : null;
  } while (cursor);
  return ids;
}

// 'cestino' | 'viva' | 'sparita'
function statoPagina_(id) {
  try {
    var p = notion_('get', '/pages/' + id);
    return p.archived || p.in_trash ? 'cestino' : 'viva';
  } catch (err) {
    if (/Notion 404/.test(err.message)) return 'sparita';
    throw err;   // errore di rete o simile: meglio non fare niente in questo giro
  }
}

function unici_(a) { var v = {}; return a.filter(function (x) { return v[x] ? false : (v[x] = true); }); }
