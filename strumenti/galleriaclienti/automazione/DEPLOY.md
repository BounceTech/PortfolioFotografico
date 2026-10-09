# Log galleria → Notion + Telegram: come aggiornarlo

Lo script gira su Google (Apps Script), collegato al Foglio Google delle selezioni.
L'URL `/exec` resta lo stesso: la galleria non va toccata.

## 1. Token Notion
1. Vai su **notion.so/profile/integrations** → apri l'integrazione che usi (o *New integration*, tipo Internal).
2. Copia l'**Internal Integration Secret** (`ntn_…` o `secret_…`).
3. In Notion apri il database **Lavori** → `•••` in alto a destra → **Connessioni** → aggiungi quell'integrazione.
   Senza questo passaggio Notion risponde "object not found" e il log non viene scritto.

## 2. Proprietà dello script
Nell'editor Apps Script: **Impostazioni progetto** (ingranaggio) → **Proprietà script** → aggiungi:

| Proprietà | Valore |
|---|---|
| `NOTION_TOKEN` | il secret del punto 1 |
| `TELEGRAM_TOKEN` | token del bot (BotFather) |
| `TELEGRAM_CHAT` | id della chat dove vuoi le notifiche |

Se il vecchio codice aveva questi valori scritti in cima, copiali da lì prima di sostituirlo.

## 3. Codice
1. Editor → file `Codice.gs` → seleziona tutto → incolla il contenuto di `automazione/Codice.gs`.
2. Salva.
3. In alto scegli la funzione **verifica** → **Esegui** (la prima volta autorizza i permessi).
   Nel registro devi vedere `Notion: DB Lavori raggiungibile ✅` e ricevere un messaggio di prova su Telegram.

## 4. Pubblica la nuova versione (stesso URL)
**Esegui il deployment → Gestisci deployment** → matita sul deployment esistente →
Versione: **Nuova versione** → **Esegui il deployment**.

Non creare un deployment nuovo: cambierebbe l'URL.

## Cosa compare in Notion
Nella pagina del lavoro (Nome servizio = nome della galleria, es. `260919_DomesticaCatering_CortePeron`):

```
🔗 Link galleria: https://mattiabuoli.it/galleriaclienti/260919_DomesticaCatering_CortePeron/
📋 Log galleria
🕐 30/09/2026 15:23 — 👀 Il cliente ha aperto la galleria (Wegloo)
🕐 30/09/2026 15:40 — ✅ Il cliente ha inviato la selezione (Wegloo) — 12 foto
Selezione:
┌──────────────────────────────┐
│ 260919_DomesticaCatering_…   │  ← blocco codice: passa sopra e premi "Copia"
│ PIC08150                     │
│ PIC08151 — nota del cliente  │
└──────────────────────────────┘
```

Su invio della selezione lo Status passa a **Selezione fatta**. Se la pagina non esiste viene creata
(e Telegram ti avvisa se qualcosa non va con Notion).
