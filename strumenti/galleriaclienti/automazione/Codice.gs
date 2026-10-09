/**
 * Log galleria clienti — Google Apps Script
 * by Mattia Buoli
 *
 * La galleria invia qui gli eventi (doPost, JSON):
 *   { type: 'open',   job, person, url }                         → il cliente ha aperto la galleria
 *   { type: 'submit', job, person, url, names, selections, text } → il cliente ha inviato la selezione
 *
 * Per ogni evento:
 *   1. Notion: nella pagina del DB "Lavori" con Nome servizio = job appende
 *        🔗 Link galleria: https://mattiabuoli.it/galleriaclienti/…   (una volta, sotto il titolo del log)
 *        🕐 30/09/2026 15:23 — 👀 Il cliente ha aperto la galleria
 *        🕐 30/09/2026 15:40 — ✅ Il cliente ha inviato la selezione (12 foto)
 *        Selezione:
 *        [blocco codice con il testo da copiare — pulsante "Copia" di Notion]
 *      Se la pagina non esiste la crea, così il log non si perde mai.
 *      Su submit porta lo Status a "Selezione fatta".
 *   2. Telegram: notifica di backup (e avviso se Notion fallisce).
 *   3. Foglio "Log": una riga per evento (archivio).
 *
 * Configurazione: Proprietà script (Impostazioni progetto) oppure file Config.gs con
 *   var CONFIG = { NOTION_TOKEN: '…', TELEGRAM_TOKEN: '…', TELEGRAM_CHAT: '…' };
 *   NOTION_TOKEN    token dell'integrazione Notion (collegata al DB Lavori)
 *   TELEGRAM_TOKEN  token del bot
 *   TELEGRAM_CHAT   id della chat dove ricevere le notifiche
 * Prova: esegui la funzione verifica() dall'editor. Deploy: vedi DEPLOY.md
 */

var NOTION_DB_LAVORI = '18a937f0-1525-8106-87ab-f6eae3a2d196';   // DB Lavori (non cambiare)
var TITLE_PROP       = 'Nome servizio';
var STATUS_PROP      = 'Status';
var STATUS_SCELTA    = 'Selezione fatta';
var FUSO             = 'Europe/Rome';
var SHEET_NAME       = 'Log';
var TITOLO_LOG       = '📋 Log galleria';
var PREFISSO_LINK    = '🔗 Link galleria: ';
var SITO_GALLERIE    = 'https://mattiabuoli.it/galleriaclienti/';

// Valori: Proprietà script, oppure il file Config.gs (solo su Google, mai nella repo pubblica)
function conf_(k) {
  var v = PropertiesService.getScriptProperties().getProperty(k);
  if (v) return v;
  return (typeof CONFIG !== 'undefined' && CONFIG[k]) || '';
}

// ===== ENTRATA =====

function doPost(e) {
  var esito = { ok: true };
  try {
    var d      = JSON.parse(e.postData.contents);
    var type   = d.type === 'open' ? 'open' : 'submit';
    var job    = String(d.job || '').trim().slice(0, 200);
    var person = String(d.person || 'Cliente').trim().slice(0, 80) || 'Cliente';
    if (!job) throw new Error('job mancante');
    var url    = String(d.url || '').trim().slice(0, 300);
    if (url.indexOf(SITO_GALLERIE) !== 0) url = '';   // solo link delle mie gallerie

    var sels = Array.isArray(d.selections) ? d.selections
             : (Array.isArray(d.names) ? d.names : []).map(function (n) { return { id: n, comment: '' }; });
    sels = sels.map(function (s) { return { id: String(s.id), comment: String(s.comment || '') }; })
               .sort(function (a, b) { return a.id.localeCompare(b.id, undefined, { numeric: true }); });
    var testo = String(d.text || '').trim() || testoSelezione_(job, sels);
    var ora   = Utilities.formatDate(new Date(), FUSO, 'dd/MM/yyyy HH:mm');

    try { archivia_(ora, type, job, person, sels.length, testo); } catch (err) {}

    try {
      esito.notion = logNotion_(type, job, person, ora, sels.length, testo, url);
    } catch (err) {
      esito.ok = false;
      esito.notion = 'ERRORE: ' + err.message;
    }
    esito.telegram = notifyTelegram_(type, job, person, ora, sels.length, testo, esito.ok ? '' : esito.notion);
  } catch (err) {
    esito = { ok: false, error: String(err.message || err) };
    notifyTelegram_('errore', '', '', '', 0, '', esito.error);
  }
  return json_(esito);
}

function doGet() { return json_({ ok: true, servizio: 'log galleria clienti' }); }

// Stesso formato del messaggio WhatsApp della galleria: è quello che incolli in Lightroom
function testoSelezione_(job, sels) {
  return job + '\n\n' + sels.map(function (s) { return s.comment ? s.id + ' — ' + s.comment : s.id; }).join('\n');
}

// ===== NOTION =====

function logNotion_(type, job, person, ora, n, testo, url) {
  if (!conf_('NOTION_TOKEN')) throw new Error('NOTION_TOKEN non impostato nelle proprietà script');

  var pagina = trovaPagina_(job), creata = false;
  if (!pagina) { pagina = creaPagina_(job); creata = true; }

  var chi = person && person !== 'Cliente' ? ' (' + person + ')' : '';
  var stato = statoLog_(pagina), blocchi = [];
  if (!stato.titolo) {
    blocchi.push({ object: 'block', type: 'heading_3', heading_3: { rich_text: rt_(TITOLO_LOG) } });
    if (url) blocchi.push(linkGalleria_(url));
  } else if (url && !stato.link) {
    // Log già iniziato senza link: lo inserisco subito sotto il titolo
    notion_('patch', '/blocks/' + pagina + '/children', { children: [linkGalleria_(url)], after: stato.titolo });
  }
  if (type === 'open') {
    blocchi.push(par_('🕐 ' + ora + ' — 👀 Il cliente ha aperto la galleria' + chi));
  } else {
    blocchi.push(par_('🕐 ' + ora + ' — ✅ Il cliente ha inviato la selezione' + chi + ' — ' + n + ' foto', true));
    blocchi.push(par_('Selezione:'));
    blocchi.push({ object: 'block', type: 'code', code: { language: 'plain text', rich_text: rt_(testo) } });
  }
  notion_('patch', '/blocks/' + pagina + '/children', { children: blocchi });

  if (type === 'submit') {
    var props = {};
    props[STATUS_PROP] = { status: { name: STATUS_SCELTA } };
    notion_('patch', '/pages/' + pagina, { properties: props });
  }
  return (creata ? 'pagina creata e ' : '') + 'log scritto';
}

function trovaPagina_(job) {
  var filtro = { property: TITLE_PROP, title: { equals: job } };
  var r = notion_('post', '/databases/' + NOTION_DB_LAVORI + '/query', { filter: filtro, page_size: 1 });
  return r.results && r.results.length ? r.results[0].id : null;
}

function creaPagina_(job) {
  var props = {};
  props[TITLE_PROP] = { title: rt_(job) };
  var r = notion_('post', '/pages', { parent: { database_id: NOTION_DB_LAVORI }, icon: { type: 'emoji', emoji: '📷' }, properties: props });
  return r.id;
}

// { titolo: id del blocco "📋 Log galleria" o null, link: true se il link galleria c'è già }
function statoLog_(pagina) {
  var stato = { titolo: null, link: false }, cursor = null;
  var testo = function (b) { return (b[b.type].rich_text || []).map(function (t) { return t.plain_text; }).join(''); };
  do {
    var r = notion_('get', '/blocks/' + pagina + '/children?page_size=100' + (cursor ? '&start_cursor=' + cursor : ''));
    for (var i = 0; i < r.results.length; i++) {
      var b = r.results[i];
      if (b.type === 'heading_3' && testo(b) === TITOLO_LOG) stato.titolo = b.id;
      if (b.type === 'paragraph' && testo(b).indexOf(PREFISSO_LINK) === 0) stato.link = true;
    }
    cursor = r.has_more ? r.next_cursor : null;
  } while (cursor);
  return stato;
}

function linkGalleria_(url) {
  return { object: 'block', type: 'paragraph', paragraph: { rich_text: [
    { type: 'text', text: { content: PREFISSO_LINK } },
    { type: 'text', text: { content: url, link: { url: url } } }
  ] } };
}

// Notion accetta max 2000 caratteri per pezzo di testo: le selezioni lunghe vengono spezzate
function rt_(testo) {
  var out = [], s = String(testo);
  for (var i = 0; i < s.length && out.length < 100; i += 2000) out.push({ type: 'text', text: { content: s.slice(i, i + 2000) } });
  return out.length ? out : [{ type: 'text', text: { content: '' } }];
}

function par_(testo, grassetto) {
  var r = rt_(testo);
  if (grassetto) r.forEach(function (t) { t.annotations = { bold: true }; });
  return { object: 'block', type: 'paragraph', paragraph: { rich_text: r } };
}

function notion_(metodo, percorso, corpo) {
  var opt = {
    method: metodo,
    headers: { 'Authorization': 'Bearer ' + conf_('NOTION_TOKEN'), 'Notion-Version': '2022-06-28' },
    contentType: 'application/json',
    muteHttpExceptions: true
  };
  if (corpo) opt.payload = JSON.stringify(corpo);
  var res = UrlFetchApp.fetch('https://api.notion.com/v1' + percorso, opt);
  var data = JSON.parse(res.getContentText() || '{}');
  if (res.getResponseCode() >= 300) throw new Error('Notion ' + res.getResponseCode() + ': ' + (data.message || res.getContentText()));
  return data;
}

// ===== TELEGRAM (backup) =====

function notifyTelegram_(type, job, person, ora, n, testo, errore) {
  var token = conf_('TELEGRAM_TOKEN'), chat = conf_('TELEGRAM_CHAT');
  if (!token || !chat) return 'non configurato';
  var msg;
  if (type === 'open')        msg = '👀 Galleria aperta\n' + job + '\n' + person + ' — ' + ora;
  else if (type === 'submit') msg = '✅ Selezione inviata (' + n + ' foto)\n' + person + ' — ' + ora + '\n\n' + testo;
  else if (type === 'prova')  msg = '🧪 Prova collegamento log galleria: Telegram funziona';
  else                        msg = '⚠️ Errore log galleria';
  if (errore) msg += '\n\n⚠️ Notion: ' + errore;
  try {
    var r = UrlFetchApp.fetch('https://api.telegram.org/bot' + token + '/sendMessage', {
      method: 'post', payload: { chat_id: chat, text: msg.slice(0, 4000) }, muteHttpExceptions: true
    });
    return r.getResponseCode() === 200 ? 'inviato' : 'errore ' + r.getResponseCode();
  } catch (err) { return 'errore'; }
}

// ===== ARCHIVIO =====

function archivia_(ora, type, job, person, n, testo) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  if (!ss) return;
  var sh = ss.getSheetByName(SHEET_NAME) || ss.insertSheet(SHEET_NAME);
  if (sh.getLastRow() === 0) sh.appendRow(['ora', 'evento', 'lavoro', 'cliente', 'foto', 'selezione']);
  sh.appendRow([ora, type, job, person, n, type === 'submit' ? testo : '']);
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

// ===== PROVA DALL'EDITOR =====
// Seleziona "verifica" in alto e premi Esegui: il risultato compare nel registro di esecuzione.
function verifica() {
  var righe = [];
  righe.push('NOTION_TOKEN: '   + (conf_('NOTION_TOKEN')   ? 'impostato' : 'MANCANTE'));
  righe.push('TELEGRAM_TOKEN: ' + (conf_('TELEGRAM_TOKEN') ? 'impostato' : 'mancante'));
  righe.push('TELEGRAM_CHAT: '  + (conf_('TELEGRAM_CHAT')  ? 'impostato' : 'mancante'));
  try {
    notion_('post', '/databases/' + NOTION_DB_LAVORI + '/query', { page_size: 1 });
    righe.push('Notion: DB Lavori raggiungibile ✅');
  } catch (err) {
    righe.push('Notion: ' + err.message + '  → controlla il token e che l\'integrazione sia collegata al DB Lavori (••• → Connessioni)');
  }
  righe.push('Telegram: ' + notifyTelegram_('prova', '', '', '', 0, '', '') );
  Logger.log(righe.join('\n'));
}
