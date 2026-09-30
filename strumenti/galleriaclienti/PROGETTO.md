# Galleria Clienti v3 — Documentazione
**Mattia Buoli — shooting → selezione del cliente → editing**

---

## Flusso

```
[Shooting]  →  export JPEG in AAMMGG_NomeEvento/JPG
    ↓
App "Galleria Clienti"  →  comprime le foto, genera la galleria, pubblica su GitHub Pages,
                           mette il messaggio WhatsApp negli appunti
    ↓
Cliente apre il link, inserisce la password, seleziona le foto (con note facoltative)
    ↓
Cliente preme "Invia"  →  WhatsApp / copia del messaggio
                       →  in automatico: selezione inviata ad Apps Script → Notion
    ↓
Copi il messaggio in Lightroom: Library → Plug-in Extras → Selezione cliente
    ↓
Keyword  Scelte clienti › NomeEvento › Nome  +  preset "Selezione base" + Auto Tone
```

---

## Struttura file

```
strumenti/galleriaclienti/   (dentro la repo PortfolioFotografico)
├── genera.py                  # Motore: comprime, cifra, genera, pubblica
├── template.html              # Template della galleria
├── segreti.py                 # GAS_URL (ignorato da git) — modello: segreti.example.py
├── app/                       # App Mac (SwiftUI) + build.sh
├── automazione/               # Google Apps Script: log aperture/selezioni → Notion + Telegram (vedi DEPLOY.md)
└── ScelteCliente.lrplugin/    # Plugin Lightroom (comandi manuali)
    ├── Info.lua
    ├── ImportaScelte.lua      # "Selezione cliente": legge il messaggio dagli appunti
    ├── ElaboraSelezionati.lua # "Elabora selezionati"
    └── MatchUtils.lua         # Ricerca foto nel catalogo
```

Le gallerie pubblicate stanno in `/galleriaclienti/AAMMGG_NomeEvento/` (radice della repo).

---

## Utilizzo quotidiano — app "Galleria Clienti"

Doppio clic su **Galleria Clienti** (Applicazioni / Launchpad / Dock):
1. Trascina la cartella `JPG` del lavoro (o la cartella del lavoro intera: l'app usa da sola `JPG`).
   Struttura attesa: `AAMMGG_NomeEvento/{ARW, JPG, Edit}` — il nome evento viene dalla cartella padre.
2. Scrivi il nome del cliente. Password proposta (modificabile, non cambia da sola), limite 0 = nessuno.
3. **Crea e pubblica** (⏎).

Il nome del cliente è fisso nella galleria: il cliente vede solo il campo password.

- Ricompilare l'app (solo se cambi `app/GalleriaClienti.swift` o sposti la repo): `./app/build.sh`
- Backup da terminale: `python3 genera.py`
- Ricostruire una galleria pubblicata col template attuale:
  `python3 genera.py --rigenera ../../galleriaclienti/NOME/ --password PW [--cliente NOME] [--pubblica]`

---

## Installazione su nuovo Mac

1. `pip3 install --user Pillow cryptography`
2. `git clone https://github.com/BounceTech/PortfolioFotografico.git ~/Documents/GitHub/PortfolioFotografico`
3. Copia `segreti.example.py` in `segreti.py` e inserisci `GAS_URL`
4. `./app/build.sh` → installa l'app in /Applications
5. Lightroom Classic: `File → Plug-in Manager → Add` → `strumenti/galleriaclienti/ScelteCliente.lrplugin`
6. Preset "Selezione base" in Lightroom: Develop → disegna la curva → `New Preset…` →
   spunta **solo** Tone Curve → nome esatto `Selezione base`

---

## In Lightroom

`Library → Plug-in Extras → Selezione cliente`: legge il messaggio dagli appunti, chiede il nome
di chi ha scelto e applica keyword + preset + Auto Tone.

Le foto vengono cercate nel **catalogo** per nome file (senza estensione), preferendo la cartella
del lavoro. Se una foto esiste solo in un altro lavoro non viene taggata (meglio una foto mancante
che una sbagliata) → importa le foto in Lightroom prima di elaborare la selezione.

```
Scelte clienti
└── 260612_Cherimoya_TrattoriaDaMario
    └── Carlo
```

---

## Sicurezza

- La pagina contiene in chiaro solo nome evento, limite selezioni e numero WhatsApp.
- Lista foto, nome cliente e URL Apps Script sono in un **vault cifrato con la password**
  (PBKDF2-SHA256 200k iterazioni + AES-256-GCM, decifrato nel browser con WebCrypto).
  Password sbagliata = decifratura fallita: nel sorgente non c'è nessuna password da confrontare.
- Le foto compresse non hanno EXIF (niente GPS / dati camera).
- **Limite noto:** la repo è pubblica, quindi le foto compresse restano scaricabili da chi conosce
  l'URL esatto o sfoglia GitHub; nella cronologia git restano le vecchie password in base64.
  Per chiudere davvero: repo privata + hosting che la supporti (es. Cloudflare Pages).

---

## Riferimenti

| Cosa | Dove |
|------|------|
| URL Apps Script | `segreti.py` (ignorato da git) |
| GitHub repo | `https://github.com/BounceTech/PortfolioFotografico` |
| Sito | `https://mattiabuoli.it` |
