# Galleria Clienti v3 — Documentazione completa
**Mattia Buoli — Sistema automatico shooting → selezione → editing**

---

## Panoramica del flusso

```
[Shooting]
    ↓
genera.py  →  comprime le foto, genera la galleria HTML, pubblica su GitHub Pages
    ↓
Cliente apre il link, fa login, seleziona le foto
    ↓
Cliente preme "Invia" → messaggio silenzioso al bot Telegram
    ↓
Watcher (plugin Lightroom) riceve il messaggio ogni 15 secondi
    ↓
Applica keyword  Scelte clienti › NomeEvento › NomeCliente
Applica preset "Selezione base" (curva contrasto)
Applica Auto Tone (Exposure, Highlights, Shadows, Whites, Blacks) foto per foto
    ↓
Notifica Telegram: "✅ Carlo — 260612_Cherimoya — 15/15 foto elaborate"
    ↓
[Tu apri Lightroom e fai solo maschere + tocco creativo]
```

---

## Struttura file del progetto

```
strumenti/galleriaclienti/   (dentro la repo PortfolioFotografico)
├── genera.py                        # Script principale — genera e pubblica la galleria
├── template.html                    # Template HTML della galleria (non toccare a mano)
├── segreti.py                       # Segreti (ignorato da git)
├── app/                             # App Mac (SwiftUI) + build.sh
└── ScelteCliente.lrplugin/         # Plugin Lightroom
    ├── Info.lua                     # Manifest del plugin
    ├── Watcher.lua                  # Cuore del sistema — polling Telegram + elaborazione
    ├── ImportaScelte.lua            # Comando manuale (incolla messaggio dagli appunti)
    ├── MatchUtils.lua               # Logica di ricerca foto condivisa
    └── Stato.lua                    # Mostra stato watcher in LR
```

---

## Configurazione — valori da tenere aggiornati

I segreti **non** stanno nel codice (la repo è pubblica): sono in due file ignorati da git.

### `segreti.py` (accanto a `genera.py`) — modello: `segreti.example.py`
```python
TELEGRAM_TOKEN, TELEGRAM_CHAT, MASTER_KEY, GAS_URL
```

### `ScelteCliente.lrplugin/Segreti.lua` — modello: `Segreti.example.lua`
```lua
TELEGRAM_TOKEN, CHANNEL_ID, NOTIFY_ID, MASTER_KEY
```

`MASTER_KEY` deve essere identica nei due file e non va mai cambiata.
Le impostazioni non segrete (`WHATSAPP_NUM`, `SITO_BASE`, `PRESET_NAME`…) restano in cima a `genera.py` e `Watcher.lua`.

---

## Installazione su nuovo Mac

### 1. Dipendenze Python
```bash
pip install Pillow
```

### 2. Git e repo
```bash
# Clona la repo del sito (quella che pubblichi su GitHub Pages)
git clone https://github.com/BounceTech/PortfolioFotografico.git \
  /Users/TUO_NOME/Documents/GitHub/PortfolioFotografico
```
`REPO_DIR` si calcola da solo (è la radice della repo). Crea `segreti.py` e `ScelteCliente.lrplugin/Segreti.lua` dai file `.example`.

### 3. Installa il plugin in Lightroom Classic
1. Apri Lightroom Classic
2. `File → Plug-in Manager → Add`
3. Seleziona la cartella `strumenti/galleriaclienti/ScelteCliente.lrplugin`
4. Clicca `Done`
5. **Esci completamente da Lightroom e riaprilo** (obbligatorio per registrare `LrInitPlugin`)

### 4. Crea il preset "Selezione base" in Lightroom
1. Vai nel modulo **Develop**
2. Apri una foto RAW qualsiasi
3. Disegna la tua **curva di contrasto** nel pannello Tone Curve
4. `Develop → New Preset…`
5. Nella finestra: deseleziona tutto, rispunta **solo** `Tone Curve`
6. Nome: **`Selezione base`** (esatto, spazio incluso)
7. Salva

> Il preset applica solo la curva. Tutto il resto (Exposure, Highlights, Shadows,
> Whites, Blacks) viene calcolato automaticamente dal watcher con Auto Tone.

### 5. Avvia il watcher
- `Library → Plug-in Extras → Avvia watcher selezioni (auto)`
- Dovresti ricevere su Telegram: 🟢 Watcher attivo

---

## Utilizzo quotidiano — app "Galleria Clienti"

Doppio clic su **Galleria Clienti** (in Applicazioni / Launchpad / Dock):
1. Trascina la cartella delle foto esportate nella finestra (o sull'icona nel Dock)
2. Il nome evento si compila dal nome della cartella → nomina le cartelle `AAMMGG_NomeEvento`
3. Scrivi il nome del cliente (la password viene proposta, puoi cambiarla)
4. **Crea e pubblica** (⏎)

Comprime le foto in parallelo, genera la pagina, fa commit + push solo di quella galleria
e mette il messaggio WhatsApp negli appunti.

- Ricompilare l'app (solo se cambi `app/GalleriaClienti.swift` o sposti la repo): `./app/build.sh`
- Backup da terminale: `python3 genera.py`
- Ricostruire gallerie già pubblicate col template attuale: `python3 genera.py --rigenera ../../galleriaclienti/NOME/ [--pubblica]`
- Dipendenze Python: `pip3 install --user Pillow cryptography`

---

## Come funziona il matching foto

Il watcher cerca nel **catalogo Lightroom** (non su disco) le foto per nome stem (senza estensione, case-insensitive).

Regola di sicurezza: se una foto esiste nel catalogo ma **solo in un altro lavoro**, NON viene taggata (segnalata come "ambigua"). Meglio una foto non trovata che una foto del lavoro sbagliato.

→ Per questo è fondamentale che le foto siano **importate in Lightroom** prima che il cliente selezioni.

---

## Sicurezza

### Secret HMAC
Ogni galleria contiene un codice segreto di 16 caratteri calcolato come:
```
HMAC-SHA256(MASTER_KEY, nome_evento)[:16]
```
Il watcher rifiuta qualsiasi messaggio Telegram che non abbia il SECRET corretto.
→ Chiunque vedesse il token del bot nel sorgente HTML non può forgiare messaggi validi senza conoscere il `MASTER_KEY`.

### Password e dati della galleria
La pagina contiene in chiaro solo nome evento, limite e numero WhatsApp.
Lista foto, token Telegram, SECRET e URL Apps Script sono in un **vault cifrato con la password**
(PBKDF2-SHA256 200k iterazioni + AES-256-GCM, decifrato nel browser con WebCrypto).
Password sbagliata = decifratura fallita: non esiste una password "da confrontare" nel sorgente.
Le foto compresse non hanno EXIF (niente GPS / dati camera).

### Limite noto: repo pubblica
Le foto compresse restano scaricabili da chi conosce l'URL esatto o sfoglia la repo su GitHub.
Nella cronologia git restano anche le vecchie password in base64 (gallerie precedenti alla v3).
Per chiudere davvero: repo privata + hosting che la supporti (es. Cloudflare Pages).

---

## Formato messaggio Telegram

```
SELEZIONE|JOB=260612_Cherimoya_TrattoriaDaMario|NOME=Carlo|FOTO=PIC05154 PIC05153 PIC05131|SECRET=a3f8c2d1e9b7f4a2
```

Il watcher parse questo messaggio e:
1. Estrae `JOB` → cartella del lavoro nel catalogo LR
2. Estrae `NOME` → terzo livello della keyword (`Scelte clienti › JOB › NOME`)
3. Estrae `FOTO` → lista stem dei file da cercare
4. Verifica `SECRET` → se non valido, rifiuta senza taggare niente

---

## Keyword hierarchy in Lightroom

```
Scelte clienti
└── 260612_Cherimoya_TrattoriaDaMario
    ├── Carlo
    └── Laura
└── 260529_DonegalPub
    └── Marco
```

Per trovare tutte le foto selezionate da Carlo per Cherimoya:
- `Library → Filter Bar → Metadata → Keywords → Scelte clienti → 260612_... → Carlo`

---

## Stato e debug

### Controlla stato watcher
`Library → Plug-in Extras → Stato watcher selezioni`

Mostra: avviato alle, ultimo poll (N secondi fa), ultima selezione applicata, ultimi errori.

### Log completo
```bash
tail -f ~/scelte_watcher.log
```

Ogni poll scrive una riga. Quando arriva una selezione:
```
15:01:44  poll offset=384880056  body=347 byte
15:01:44    update ricevuti: 1
15:01:44    message chat=<chat_id> text=SELEZIONE|JOB=260612_...
15:01:44    SELEZIONE job=260612_Cherimoya persona=Carlo nfoto=15
15:01:46    -> taggate 15/15  ambigue=0  assenti=0
```

### Il watcher si ferma da solo?
È normale che al doppio avvio (LrInitPlugin + click manuale) uno dei due si fermi.
Il log riporta `watcher fermato (gen cambiata)` — è il meccanismo anti-duplicato, non un errore.
L'istanza sopravvissuta continua a girare normalmente.

---

## Comando manuale (backup)

Se per qualsiasi motivo il watcher non riceve il messaggio automatico:
1. Copia il testo della selezione
2. `Library → Plug-in Extras → Scelte cliente (incolla messaggio)`
3. Il plugin legge gli appunti e applica le keyword

---

## Requisiti per il funzionamento automatico

| Requisito | Note |
|-----------|------|
| Mac acceso (anche in sospensione) | I messaggi Telegram restano in coda — vengono processati alla riapertura di LR |
| Lightroom Classic aperto | Il watcher gira dentro LR |
| Watcher avviato | Una volta per sessione LR |
| Connessione internet | Per polling Telegram ogni 15 sec |
| Foto importate nel catalogo LR | Prima che il cliente selezioni |
| Preset "Selezione base" creato | Una volta sola |

> Il Mac può stare in sospensione — la connessione si risveglia automaticamente
> per le app aperte su macOS. Se LR è aperto, il watcher continua a girare.
> Se il Mac era spento, al riavvio di LR il watcher processa tutti i messaggi
> in coda automaticamente.

---

## Versioni e tecnologie

- Python 3.x + Pillow
- Lightroom Classic (testato su LR 11+)
- Lua 5.1 (runtime LR)
- Telegram Bot API (polling, no webhook)
- GitHub Pages (hosting galleria)
- HMAC-SHA256 via openssl CLI (sicurezza messaggi)

---

## Credenziali — tienile al sicuro

| Cosa | Dove |
|------|------|
| Bot token Telegram | `segreti.py` e `Segreti.lua` (ignorati da git) |
| MASTER_KEY | `segreti.py` e `Segreti.lua` — non deve mai cambiare una volta in produzione |
| Chat ID (notifiche + Inbox Selezioni) | `Segreti.lua` |
| GitHub repo | `https://github.com/BounceTech/PortfolioFotografico` |
| Sito | `https://mattiabuoli.it` |
