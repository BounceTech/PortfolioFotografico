# Design System — mattiabuoli.it · v2 "Bronzo & Pellicola" (10.2026)

Riferimento unico di come è costruito il sito (`index.html` e `404.html`). Le tavole originali in PDF stanno in `_design/tavole/` (solo sul Mac: 01 Home desktop, 02 Home mobile, 03 Galleria Motorsport, 04 Design system). Se cambia qualcosa nel codice, aggiorna anche questo file.

> Nero caldo come una camera oscura, oro-bronzo come firma, carta per le pause. Le foto sono l'unico colore saturo della pagina.

## Palette

| Token CSS | Hex | Nome | Uso |
|---|---|---|---|
| `--ink` | `#0E0C0A` | Inchiostro | fondo pagina |
| `--surface` | `#171410` | Superficie | contatti, CTA galleria, sfondo foto in caricamento |
| `--line` | `#2E2820` | Linea | bordi, separatori |
| `--line-strong` | `#5A4A33` | — | bordo dei bottoni secondari |
| `--bone` | `#EFE6D6` | Osso | testo |
| `--bone-2` | `#B8AE9C` | — | testo secondario |
| `--paper` | `#EEE6D8` | Carta | l'unica sezione chiara (Come lavoro) |
| `--paper-ink` / `--paper-ink-2` | `#1A1612` / `#4A4237` | — | testo su carta |
| `--gold` | `#C9A46A` | **Oro — primario** | CTA, kicker, link, parola hero, corsivi |
| `--gold-light` | `#E3CB9C` | Oro chiaro | hover |
| `--bronze` | `#8E6A3E` | Bronzo | solo decorativo: ✦, dettagli (contrasto 4:1, non per testo piccolo) |
| `--bronze-text` | `#A47E4C` | — | bronzo leggibile per testi piccoli su nero (categorie "BUSINESS"/"MOTORSPORT") |
| `--bronze-dark` | `#7A5A32` | Bronzo scuro | oro su carta (kicker, numeri, corsivo) |

Contrasti verificati (WCAG AA): oro su inchiostro 8.4, osso-2 su inchiostro 8.9, bronzo scuro su carta 5.1, inchiostro su oro 8.4.

## Tipografia

| Font | Variabile | Ruolo | Note |
|---|---|---|---|
| **Instrument Serif** (+ corsivo) | `--serif` | Display: titoli, BUOLI, numeri dei passi, citazione, nomi canali | 500 · 240 · 104 · 64 · 44 px; caricato con `display=block` per non far "saltare" la scritta BUOLI |
| **Archivo** (asse larghezza 100–125) | `--sans` | Testo e UI | 17 / 16 / 15 px · 400–600; il marchio "MATTIA BUOLI" usa larghezza 112% |
| **IBM Plex Mono** | `--mono` | Dettagli: kicker, menu, didascalie N°, coordinate | 12–13 px, maiuscolo, spaziatura 0.12–0.18em |

## Regole

1. **L'oro è firma, non sfondo.** Parola hero, CTA, kicker, corsivi chiave. Mai grandi campiture (eccezione: il riquadro WhatsApp nei contatti).
2. **Una parola in corsivo.** Ogni titolo ha al massimo una frase in corsivo oro (`<em>`): è la voce di Mattia.
3. **Provino a contatto.** Ogni foto ha la sua didascalia `N°xx — Titolo` in mono. Grana pellicola su tutta la pagina.
4. **Una pausa chiara.** Una sola sezione su carta per pagina (Come lavoro): dà respiro e fa risaltare il metodo.
5. **Un solo bottone oro per schermata: è sempre WhatsApp.** In home l'header ha "Parliamone" a contorno; in galleria diventa oro (non c'è un altro oro in alto). La barra fissa su telefono compare solo dopo l'apertura e sparisce nei contatti.

## Componenti

- **Bottoni**: `.btn` (contorno `--line-strong`), `.btn-gold` (WhatsApp, icona chat), `.link-arrow` ("Vedi la galleria →").
- **Mirino** (`.vf`): parentesi angolari oro in alto a sinistra e in basso a destra al passaggio/focus su card e foto. Anche nella foto ingrandita e nella 404.
- **Kicker** (`.kicker`): mono oro maiuscolo, numerato per sezione ("01 — Cosa faccio").
- **Didascalia** (`.caption`): `N°xx — TITOLO` a sinistra, categoria in `--bronze-text` a destra (solo mosaico e foto grande).

## Struttura della home

| # | Sezione | id | Note |
|---|---|---|---|
| — | Hero | `#home` | "Mattia" corsivo + **BUOLI** gigante oro (h1), ritaglio `images/sito/hero-cutout.webp` (png di riserva) davanti alle lettere con sfumatura in basso, coordinate in alto a destra, claim "Fotografia per aziende che lavorano bene — *dal ristorante al paddock.*", WhatsApp oro + "Guarda i lavori" |
| — | Clienti | — | "Hanno scelto di lavorare con me": ByTiffany ✦ Wegloo ✦ Bar Venezia Mantova ✦ MarkThink ✦ Cherimoya — presi dal database **Lavori** su Notion (aziende con lavori collegati, in ordine di numero di lavori; esclusi privati ed eventi di famiglia). Si aggiornano a mano |
| 01 | Cosa faccio | `#lavori` | due card 4:5 (Business & Eventi, Motorsport) con copertina = prima foto della cartella; sotto la riga secondaria **Extra** (3 miniature, testo "Non è la mia specialità, ma capita…") |
| 02 | Lavori selezionati | `#selezione` | mosaico di 7 foto (righe 7/5 · 4/8 · 5/4/3 colonne): foto 2–5 di Business e 2–4 di Motorsport nell'ordine B B M M B M B |
| 03 | Come lavoro | `#metodo` | su carta; 3 passi con numeri serif, promesse ✦ in mono |
| 04 | Chi sono | `#chi-sono` | foto `profile.jpg` + "Piacere, *Mattia.*" + tabella valori (su telefono diventano 3 etichette) |
| 05 | Dicono di me | `#recensioni` | citazione corsiva centrata |
| 06 | Contatti | `#contatti` | superficie con alone oro; "Parliamo del tuo *progetto.*"; 3 riquadri (WhatsApp oro, Email, Instagram); footer con "Buoli" oro e P.IVA |

Su telefono (≤768 px) alcuni testi hanno una versione più breve: nel codice `<span class="d">` (computer) e `<span class="m">` (telefono), come nella tavola mobile.

## Pagina galleria

Una sola pagina (`#gallery-page`) riempita da `apriGalleria(key)`: indietro "← Tutti i lavori", titolo gigante con una parte in corsivo (Business & *Eventi*, Motor*sport*, *Extra*), descrizione + "Per: …", schede delle tre gallerie con il conteggio su quella aperta, **foto grande = prima foto orizzontale** della cartella (le verticali tagliate a 2:1 si rovinano), poi le altre in 3 colonne (2 su tablet, 1 su telefono) con didascalia, CTA su superficie "Ti piace questo stile? … *Raccontamelo.*" + WhatsApp con messaggio specifico per galleria.

Indirizzi: `#galleria-Business`, `#galleria-Motori`, `#galleria-Extra`. I vecchi link restano validi via `galleryAlias`: `#galleria-Aziende`/`#galleria-Eventi` → Business, `#galleria-Sport` → Extra. Una galleria con 0 foto non si apre (e sparisce dalle schede; la riga Extra sparisce se Extra è vuota).

## Sistema foto → sito

`FOTO/` contiene **solo tre cartelle**: `Business e eventi`, `Motorsport`, `Extra` (niente sottocartelle). Ordine sul sito = ordine dei nomi file (`01 …`, `02 …`); **il nome senza numero è la didascalia** (`05 Su strada.jpg` → "N°05 — Su strada"; i nomi automatici tipo `IMG_1234` restano senza didascalia).

`strumenti/sito/aggiorna_foto.py` (mappa `GALLERIE`: `business`, `motorsport`, `extra`) genera `images/galleria/<id>/` (web 2400 px + thumbs 800 px, senza EXIF/GPS) e `images/gallerie.js` (`src`, `thumb`, `w`, `h`, `titolo`); cancella le gallerie generate che non sono più in `GALLERIE` e segnala (anche con notifica) le foto messe altrove. Le pagine leggono `window.GALLERIE` tramite `galleryConfig[*].folderName`. Con l'automatico attivo (launchd) ogni modifica a `FOTO/` viene pubblicata da sola. Guida per Mattia: `COME-AGGIUNGERE-FOTO.md` nella radice.

Foto fisse in `images/sito/`: `hero-cutout.webp` + `.png` (ritaglio hero), `profile.jpg` (Chi sono), `og-cover.jpg` (anteprima link 1200×630), `favicon.png`. `hero.jpg` non è più usata dalla pagina.

Per aggiungere una galleria servono: la voce in `GALLERIE` dello script, la voce in `galleryConfig` (+ messaggio in `MSG`) e la card o riga in home.

## Accessibilità e prestazioni

- Focus visibile oro su tutto; foto ingrandibili con `<button>` (Invio/Spazio), foto ingrandita con frecce, Esc, swipe e ritorno del focus; menu mobile con `aria-expanded`.
- `prefers-reduced-motion`: niente comparse, zoom o animazione dell'hero.
- Miniature con `width`/`height` (niente salti), lazy loading, la foto grande della galleria in versione piena.
- Lighthouse 10.2026 (locale): computer 97 prestazioni · 100 accessibilità · 100 SEO; telefono 80 · 100 · 100.
