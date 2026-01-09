# 📸 Setup Portfolio Mattia Fotografo

## ✅ Step 1: Scarica i file

Hai due file:
- `index.html` - Il sito completo
- Questo README (istruzioni)

---

## 📁 Step 2: Crea la struttura cartelle

Crea questa struttura nel tuo computer:

```
mattia-portfolio/
├── index.html
├── images/
│   ├── ritratti/
│   │   ├── ritratti-1.jpg
│   │   ├── ritratti-2.jpg
│   │   └── ritratti-3.jpg
│   ├── coppie/
│   │   ├── coppie-1.jpg
│   │   ├── coppie-2.jpg
│   │   └── coppie-3.jpg
│   └── business/
│       ├── business-1.jpg
│       ├── business-2.jpg
│       └── business-3.jpg
```

**IMPORTANTE:** I nomi DEVONO essere esatti: `ritratti-1.jpg`, `ritratti-2.jpg`, ecc.

---

## 🖼️ Step 3: Rinomina le tue foto

Se hai già le foto, devi rinominarle. Usa questo script (macOS/Linux):

**Su Mac, apri Terminal e vai nella cartella con le foto:**
```bash
cd /percorso/alle/tue/foto/ritratti
```

**Poi copia e incolla questo comando:**
```bash
for i in *.jpg; do mv "$i" "ritratti-$(printf '%d\n' $((++count))).jpg"; done
```

Ripeti per `coppie` e `business` (sostituisci il nome ogni volta).

**Se usi Windows:**
1. Metti tutte le foto nella cartella (es. `ritratti`)
2. Scarica un tool gratuito come `Bulk Rename Utility`
3. Rinomina con pattern: `ritratti-1.jpg`, `ritratti-2.jpg`, ecc.

---

## 🔢 Step 4: Aggiorna il numero di foto

Apri `index.html` con un editor di testo (VSCode, Notepad++, ecc.).

Cerca questa sezione (intorno alla riga 600):

```javascript
const galleryConfig = {
    ritratti: {
        count: 15,
        title: "Ritratti",
        desc: "Sessioni dedicate a catturare l'essenza e l'emozione. Stile caldo, naturale, cinematografico."
    },
    coppie: {
        count: 15,
        title: "Auto, Moto e Passioni",
        desc: "Fotografie che celebrano ciò che ami. Energia, dettagli, stile."
    },
    business: {
        count: 15,
        title: "Business & Locali",
        desc: "Contenuti fotografici per attività, ristoranti, negozi e piccoli eventi aziendali in provincia."
    }
};
```

**Cambia i numeri in base a quante foto hai per categoria:**
- Se in `ritratti/` hai 20 foto → `count: 20`
- Se in `coppie/` hai 18 foto → `count: 18`
- Se in `business/` hai 25 foto → `count: 25`

Salva il file.

---

## 🔗 Step 5: Personalizza i dati (facoltativo)

Sempre in `index.html`, cerca queste righe e personalizza:

**WhatsApp (cerca "wa.me"):**
```html
<a href="https://wa.me/393xxxxxxxxx" class="contact-method whatsapp-primary">
```
Sostituisci `393xxxxxxxxx` con il TUO numero (es. `393401234567`)

**Email (cerca "mailto"):**
```html
<a href="mailto:mattia@example.com" class="contact-method">
```
Sostituisci `mattia@example.com` con la TUA email

**Instagram (cerca "instagram.com"):**
```html
<a href="https://instagram.com" class="contact-method">
```
Sostituisci con il link al TUO profilo Instagram

---

## 🚀 Step 6: Carica su GitHub Pages (GRATIS!)

### 6a. Crea un account GitHub (se non lo hai)
- Vai su https://github.com
- Clicca "Sign up"
- Completa la registrazione

### 6b. Crea un nuovo repository

1. Clicca il **+** in alto a destra → **New repository**
2. **Nome:** `mattia-portfolio` (o quello che preferisci)
3. **Descrizione:** "Portfolio fotografico professionale"
4. Seleziona **Public**
5. NON selezionare "Add a README file"
6. Clicca **Create repository**

### 6c. Carica i file via Web (metodo semplice)

1. Nella pagina del repository, clicca **"Add file"** → **"Upload files"**
2. Trascina (drag & drop) sulla pagina:
   - `index.html`
   - La cartella **`images`** (GitHub caricherà anche tutte le sottocartelle)
3. Scrivi un messaggio (es. "First commit: portfolio online")
4. Clicca **"Commit changes"**

### 6d. Abilita GitHub Pages

1. Vai su **Settings** (tab in alto a destra del repo)
2. Scorri fino a **"Pages"** (nel menu sinistro)
3. Under "Source", seleziona **"Deploy from a branch"**
4. Branch: seleziona **main** (o master)
5. Clicca **Save**
6. Aspetta 1-2 minuti...

### 6e. Il tuo sito è online!

GitHub ti mostrerà un link tipo:
```
https://tuousername.github.io/mattia-portfolio
```

Condividi questo link! 🎉

---

## 📝 Step 7: Aggiornare il sito

Ogni volta che vuoi aggiungere foto:

1. **Aggiungi le foto** nella cartella locale `images/ritratti` (o coppie/business)
2. **Rinominale** con i numeri nuovi (es. ritratti-21.jpg, ritratti-22.jpg)
3. **Aggiorna il numero in `index.html`** nella sezione `galleryConfig`
4. **Carica i nuovi file su GitHub:**
   - Vai nel repo → **Add file** → **Upload files**
   - O usando Git da terminale (più veloce, se conosci Git)

---

## 🎨 Personalizzazioni avanzate (opzionale)

Se vuoi cambiare colori, font, layout:

**Colori principali** (cerca `:root {` nel file):
```css
--color-accent: #d4a574;  /* Colore oro/marrone - cambia qui */
--color-text: #1a1a1a;    /* Colore testo */
--color-bg: #faf9f7;      /* Colore sfondo */
```

Prova a cambiare i codici colore (es. `#d4a574` → `#ff6b6b` per rosso, `#4ecdc4` per turchese, ecc.)

---

## ❓ Problemi comuni?

### Le foto non si vedono
- Controlla che i nomi siano **esatti**: `ritratti-1.jpg` (non `ritratti1.jpg`)
- Controlla che il numero in `galleryConfig` corrisponda alle foto presenti
- Assicurati che la cartella `images/` sia caricata (non solo i file HTML)

### Il sito appare diverso su GitHub
- Aspetta 5-10 minuti (GitHub impiega tempo per aggiornare)
- Fai Ctrl+F5 per pulire la cache del browser

### Voglio cambiare i testi
- Cerca direttamente nel file `index.html` (es. "Chi Sono", "Contattami") e sostituisci

---

## 📞 Supporto

Se hai dubbi su nomina file, GitHub o personalizzazioni, chiedi pure!

Buona fortuna con il portfolio! 🚀📸
