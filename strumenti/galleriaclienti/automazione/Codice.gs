/**
 * Cassetta postale selezioni — Google Apps Script
 * by Mattia Buoli
 *
 * - La galleria invia qui gli eventi (doPost):
 *     type=open   → cliente ha aperto la galleria
 *     type=submit → cliente ha inviato la selezione
 * - Notifica Alfred: trova la pagina corrispondente nel DB "Lavori" di Notion
 *   (stessa identica stringa del nomeEvento) e appende un blocco nel corpo.
 * - Notifica Telegram come backup.
 * - Il plugin Lightroom legge le selezioni nuove e le segna fatte (doGet).
 *
 * Deploy: vedi DEPLOY.md
 */

// ===== CONFIG — riempi questi valori =====
var TELEGRAM_TOKEN = 'INCOLLA_QUI_IL_TOKEN_DI_BOTFATHER';
var TELEGRAM_CHAT  = '-100xxxxxxxxxx';                   // id canale (numero negativo lungo)
var READ_KEY       = 'cambiami-con-una-stringa-segreta'; // stessa del plugin

// Alfred — Notion (stesso token usato dall'app)
// Incolla il token dell'integrazione Notion condivisa con il DB Lavori
var NOTION_TOKEN   = 'YOUR_NOTION_INTEGRATION_TOKEN';   // secret_...
// =========================================

// DB Lavori (ID fisso — non cambiare)
var NOTION_DB_LAVORI = '18a937f0-1525-8106-87ab-f6eae3a2d196';

var SHEET_NAME = 'Selezioni';

function sheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) {
    sh = ss.insertSheet(SHEET_NAME);
    sh.appendRow(['id', 'timestamp', 'job', 'person', 'names', 'status']);
  }
  return sh;
}

// La galleria chiama questo ad ogni evento (open o submit)
function doPost(e) {
  try {
    var data   = JSON.parse(e.postData.contents);
    var type   = String(data.type || 'submit');
    var job    = String(data.job    || '').slice(0, 200);
    var person = String(data.person || 'Cliente').slice(0, 80);
    var names  = Array.isArray(data.names) ? data.names : [];
    var nCount = names.length;

    if (type === 'open') {
      notifyTelegram_('open', job, person, 0);
      notifyAlfred_('open', job, person, 0);
      return json_({ ok: true });
    }

    // type === 'submit'
    var selections = Array.isArray(data.selections)
      ? data.selections
      : names.map(function(n) { return { id: n, comment: '' }; });
    var sh = sheet_();
    sh.appendRow([Utilities.getUuid(), new Date().toISOString(), job, person, names.join(' '), 'pending']);
    notifyTelegram_('submit', job, person, nCount);
    notifyAlfred_('submit', job, person, nCount, selections);
    return json_({ ok: true });
  } catch (err) {
    return json_({ ok: false, error: String(err) });
  }
}

// Il plugin chiama questo per leggere le selezioni nuove o segnarle fatte
function doGet(e) {
  var p = e.parameter || {};
  if (p.key !== READ_KEY) return json_({ ok: false, error: 'unauthorized' });

  var sh = sheet_();
  var rows = sh.getDataRange().getValues();

  if (p.action === 'done' && p.id) {
    for (var i = 1; i < rows.length; i++) {
      if (rows[i][0] === p.id) { sh.getRange(i + 1, 6).setValue('done'); break; }
    }
    return json_({ ok: true });
  }

  var out = [];
  for (var j = 1; j < rows.length; j++) {
    if (rows[j][5] === 'pending') {
      out.push({
        id: rows[j][0],
        job: rows[j][2],
        person: rows[j][3],
        names: String(rows[j][4]).split(/\s+/).filter(function (s) { return s; })
      });
    }
  }
  return json_({ ok: true, pending: out });
}

// ===== NOTIFICHE =====

function notifyTelegram_(type, job, person, n) {
  if (!TELEGRAM_TOKEN || TELEGRAM_TOKEN.indexOf('INCOLLA') === 0) return;
  var text = type === 'open'
    ? '👀 Galleria aperta\n' + job + '\nDa: ' + person
    : '📸 Selezione inviata\n' + job + '\nDa: ' + person + '\nFoto: ' + n;
  try {
    UrlFetchApp.fetch('https://api.telegram.org/bot' + TELEGRAM_TOKEN + '/sendMessage', {
      method: 'post',
      payload: { chat_id: TELEGRAM_CHAT, text: text },
      muteHttpExceptions: true
    });
  } catch (err) {}
}

// Trova la pagina nel DB Lavori con Nome servizio = job,
// appende il log nel corpo e (su submit) aggiorna lo Status a "Selezione fatta".
function notifyAlfred_(type, job, person, nCount, selections) {
  if (!NOTION_TOKEN || NOTION_TOKEN.indexOf('YOUR') === 0) return;

  var now = Utilities.formatDate(new Date(), 'Europe/Rome', 'dd/MM/yyyy HH:mm');

  try {
    // 1. Cerca la pagina Lavori con Nome servizio = job
    var queryRes = UrlFetchApp.fetch('https://api.notion.com/v1/databases/' + NOTION_DB_LAVORI + '/query', {
      method: 'post',
      headers: notionHeaders_(),
      payload: JSON.stringify({
        filter: { property: 'Nome servizio', title: { equals: job } },
        page_size: 1
      }),
      muteHttpExceptions: true
    });

    var queryData = JSON.parse(queryRes.getContentText());
    if (!queryData.results || queryData.results.length === 0) return;

    var pageId = queryData.results[0].id;

    if (type === 'open') {
      // Solo apertura galleria: una riga semplice
      UrlFetchApp.fetch('https://api.notion.com/v1/blocks/' + pageId + '/children', {
        method: 'patch',
        headers: notionHeaders_(),
        payload: JSON.stringify({
          children: [{
            object: 'block', type: 'paragraph',
            paragraph: { rich_text: [{ type: 'text', text: { content: '👀 Galleria aperta — ' + person + ' — ' + now } }] }
          }]
        }),
        muteHttpExceptions: true
      });
      return;
    }

    // type === 'submit': intestazione in grassetto + lista puntata foto/commenti
    var children = [];

    // Riga intestazione
    children.push({
      object: 'block', type: 'paragraph',
      paragraph: {
        rich_text: [{
          type: 'text',
          text: { content: '📸 Selezione inviata — ' + person + ' — ' + nCount + ' foto — ' + now },
          annotations: { bold: true }
        }]
      }
    });

    // Una voce per ogni foto (con commento se presente)
    var sels = Array.isArray(selections) ? selections : [];
    sels.sort(function(a, b) { return String(a.id).localeCompare(String(b.id), undefined, { numeric: true }); });
    sels.forEach(function(s) {
      var text = s.id + (s.comment ? '  →  ' + s.comment : '');
      children.push({
        object: 'block', type: 'bulleted_list_item',
        bulleted_list_item: { rich_text: [{ type: 'text', text: { content: text } }] }
      });
    });

    // 2. Appende i blocchi nel corpo della pagina
    UrlFetchApp.fetch('https://api.notion.com/v1/blocks/' + pageId + '/children', {
      method: 'patch',
      headers: notionHeaders_(),
      payload: JSON.stringify({ children: children }),
      muteHttpExceptions: true
    });

    // 3. Aggiorna Status → "Selezione fatta"
    UrlFetchApp.fetch('https://api.notion.com/v1/pages/' + pageId, {
      method: 'patch',
      headers: notionHeaders_(),
      payload: JSON.stringify({
        properties: { 'Status': { status: { name: 'Selezione fatta' } } }
      }),
      muteHttpExceptions: true
    });

  } catch (err) {}
}

function notionHeaders_() {
  return {
    'Authorization':  'Bearer ' + NOTION_TOKEN,
    'Notion-Version': '2022-06-28',
    'Content-Type':   'application/json'
  };
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
