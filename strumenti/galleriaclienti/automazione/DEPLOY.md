# Cassetta postale selezioni — come pubblicarla (una volta sola)

1. Vai su **sheets.new** (crea un nuovo Foglio Google vuoto). Sarà l'archivio delle selezioni.
2. Menu **Estensioni → Apps Script**.
3. Cancella il codice di esempio e **incolla tutto** il contenuto di `Codice.gs`.
4. In cima, riempi i **3 valori**:
   - `TELEGRAM_TOKEN` → il token di BotFather
   - `TELEGRAM_CHAT`  → l'id del canale (il numero negativo lungo `-100…`)
   - `READ_KEY`       → inventa una stringa segreta (es. `cherimoya-7x9k`); servirà anche nel plugin
5. **Salva** (icona dischetto).
6. **Deploy → New deployment**:
   - tipo: **Web app**
   - *Execute as*: **Me** (la tua mail)
   - *Who has access*: **Anyone**
   - **Deploy** → autorizza i permessi Google (accetta).
7. Copia l'**URL** che finisce per `/exec`. Tienilo da parte (servirà nel plugin e nella galleria).

## Test (30 secondi)

Apri nel browser:
```
<IL_TUO_URL_EXEC>?key=LA_TUA_READ_KEY
```
Deve rispondere:
```
{"ok":true,"pending":[]}
```
Se vedi quello → la cassetta è viva e la chiave funziona. Fatto.

(Il salvataggio + la notifica Telegram li testeremo dalla galleria nello step successivo.)
