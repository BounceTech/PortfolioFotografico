# Design System — mattiabuoli.it

Riferimento unico di tutto ciò che è stato usato per costruire il sito (il sito è `index.html`). Se cambia qualcosa nel codice, aggiorna anche questo file.

## Colori

Tema scuro, con **due colori** in gerarchia chiara — un primario e un secondario, niente di più, per non fare confusione. Il carattere e la profondità vengono dalla rampa di sfumature dentro ciascuno dei due, non da altre tinte aggiunte.

| Token | Hex | Ruolo |
|---|---|---|
| `--color-bg` | `#0e0e0e` | Sfondo di tutto il sito |
| `--color-surface` | `#151515` | Sfondo di card, gallery-item |
| `--color-text` | `#f2efe9` | Testo principale, titoli |
| `--color-text-light` | `#9b968e` | Testo secondario, descrizioni |
| `--color-border` | `#262626` | Separatori, bordi sottili |

**Primario — Azzurro** (tecnico, moderno, affidabile — la "voce" del sito ovunque non specificato altrimenti):

| Token | Hex | Uso |
|---|---|---|
| **`--color-accent`** | `#6fa3bf` | Principale: nav, CTA, link, kicker |
| `--color-accent-dark` | `#4a7891` | Hover/pressed |
| `--color-accent-light` | `#a9cbdd` | Highlight acceso, selezione testo |
| `--color-accent-muted` | `#3d5a68` | Dettaglio quieto: bordi segnaposto, numeri fantasma |
| `--color-accent-deep` | `#1f3d4d` | Nota profonda/drammatica — usata sul pilastro **Motorsport** (stesso azzurro, non un terzo colore: solo più contrasto e carattere per quel mondo) |
| `--color-accent-deep-dark` | `#142731` | Hover sulla nota profonda |

**Secondario — Bronzo/ottone** (heritage, vintage, credibilità guadagnata — usato sempre come dettaglio, mai come campo di colore dominante):

| Token | Hex | Uso |
|---|---|---|
| **`--color-heritage`** | `#b08a5c` | Principale: sezione "I Miei Valori" e "Dicono di me" |
| `--color-heritage-dark` | `#8f6d45` | Hover/pressed |
| `--color-heritage-light` | `#d9c3a0` | Nota delicata, quasi champagne |
| `--color-heritage-deep` | `#5c4429` | Nota profonda, quasi espresso — per un contrasto più importante dove serve |

**Regola d'uso**: azzurro = colore di base ovunque; bronzo = solo sui punti di credibilità/prova sociale (Valori, Recensioni). Il pilastro Motorsport non introduce un terzo colore: usa la stessa famiglia azzurro ma nella sua nota più profonda (`--color-accent-deep`), per dargli un'anima più drammatica senza rompere la gerarchia a due colori. Tecnicamente è una ridefinizione locale di `--color-accent`/`--color-accent-dark` dentro un contenitore specifico (`.philosophy`, `.reviews`, `.portfolio-card--motorsport`, `.gallery-page--motorsport`): tutto il resto (bottoni, link, mirino, numerazione) eredita la nota giusta senza toccare ogni singola regola.

## Tipografia

| Font | Ruolo | Pesi usati | Dove |
|---|---|---|---|
| **Fraunces** | Display / editoriale | 400, 500, 600 (+ 400 corsivo) | H1/H2/H3, titoli sezione, citazione recensione |
| **Inter** | Testo | 400, 500, 600 | Body text, paragrafi, bottoni |
| **Space Mono** | Monospace / dettagli editoriali | 400, 700 | Kicker ("01 — Portfolio"), etichette nav, numerazione foto, coordinate hero, footer |

Caricati da Google Fonts in un'unica richiesta (vedi `<link>` in `<head>`), nessun font locale.

## Spaziatura

| Token | Valore |
|---|---|
| `--spacing-xs` | 8px |
| `--spacing-sm` | 16px |
| `--spacing-md` | 24px |
| `--spacing-lg` | 48px |
| `--spacing-xl` | 72px |
| `--spacing-2xl` | 140px |

## Breakpoint

| Larghezza | Dove si usa |
|---|---|
| 1000px | `.gallery-grid` passa da 3 a 2 colonne |
| 900px | `.steps-grid` (Come Lavoro) passa a colonna singola |
| 768px | Nav compatta, `.about` a colonna singola, lightbox più stretto, hero-scroll nascosto |
| 600px | `.gallery-grid` a colonna singola |

## Struttura del portfolio (due specialità + Extra)

In home, sotto la filmstrip:

- due **card grandi** affiancate (una colonna su mobile), le specialità:
  - **Business & Eventi** (`Business`) — aziende, eventi, catering in un'unica galleria
  - **Motorsport** (`Motori`) — nota azzurro profondo (`.portfolio-card--motorsport`)
- sotto, una **riga secondaria** `.extra-row` per **Extra** (`Extra`): tre miniature sovrapposte, kicker, titolo "Non solo aziende e motori" e link. È volutamente più discreta delle card: raccoglie lavori occasionali (ritratti, squadre sportive…) che non sono la specialità. Se la cartella Extra è vuota la riga sparisce. Extra non entra nella filmstrip.

I vecchi link del sito precedente restano validi tramite `galleryAlias`: `#galleria-Aziende` e `#galleria-Eventi` → Business, `#galleria-Sport` → Extra. Una galleria con 0 foto non si apre neanche da link diretto.

## Sistema foto → sito

`FOTO/` contiene **solo tre cartelle**: `Business e eventi`, `Motorsport`, `Extra` (niente sottocartelle). L'ordine sul sito è l'ordine dei nomi file (`01 …`, `02 …`), la prima foto fa da copertina della card.

`strumenti/sito/aggiorna_foto.py` (mappa `GALLERIE`: `business`, `motorsport`, `extra`) genera `images/galleria/<id>/` (web 2400 px + thumbs 800 px) e `images/gallerie.js`; cancella le gallerie generate che non sono più in `GALLERIE` e segnala (anche con notifica) le foto messe altrove: altre cartelle, sottocartelle o foto sciolte in `FOTO/`. Le pagine leggono `window.GALLERIE` tramite `galleryConfig[*].folderName`. Con l'automatico attivo (launchd) ogni modifica a `FOTO/` viene pubblicata da sola. Guida: `COME-AGGIUNGERE-FOTO.md` nella radice.

Le foto fisse (hero, profilo, cover social, favicon) stanno in `images/sito/` e si cambiano sovrascrivendo il file con lo stesso nome.

Per aggiungere una galleria servono: la voce in `GALLERIE` dello script, la voce in `galleryConfig` + la sua `gallery-page`, e la card in home.

## Dettagli espressivi (oltre al colore piatto)

Per non risultare "minimal da software house" — il sito è di un fotografo, deve respirare più arte:

- **Hero con velatura azzurro-profonda**: l'overlay sopra la foto hero non è più un nero piatto, ma una sfumatura che passa per `--color-accent-deep` prima di scurirsi verso il basso (dove serve leggibilità per titolo/CTA).
- **Hover fotografico cromatico**: sia le card in home sia le miniature nelle gallerie, al passaggio del mouse, prendono una velatura azzurro-profonda diagonale invece del semplice scurimento piatto — lega il colore guida al gesto di esplorare le foto.
- **Corsivo Fraunces come accento editoriale**: alcune parole chiave (le due voci "Business & Eventi" / "Motorsport" nel sottotitolo hero, "selezionati" in Lavori, "Progetto" nei Contatti) sono in corsivo del font display — classe `.accent-italic`, riusabile ovunque serva la stessa firma calligrafica.
- **Numerazione laterale editoriale** (`.side-index`, solo da 1300px in su): un piccolo indice verticale ("01 — Portfolio", "02 — Metodo"...) sul bordo sinistro di ogni sezione principale, ispirato ai portfolio editoriali con indice a margine — rinforza l'idea di "contact sheet" già presente nella numerazione delle foto.
- **Hero più dichiarativo**, ispirato a riferimenti visti insieme:
  - `.hero-ticker`: barra con bordo bronzo che elenca i pilastri ("Business & Eventi · Catering · Motorsport") — usa il bronzo `--color-heritage` come le altre note di credibilità, estendendone l'uso anche qui.
  - `.hero h1` ha un riempimento sfumato (bronzo chiaro → colore testo) via `background-clip: text`, invece del colore piatto.
  - `.hero-frame`: cornice sottile bronzo che inquadra l'intero hero.
  - `.hero-tagline`: piccola tagline corsiva in alto a destra ("Immagini che raccontano. Risultati che restano."), nascosta sotto i 900px.

  **Nota aperta**: il riferimento con foto-ritratto integrata nella scritta gigante (tipo "CREATIVE" di Sultan Karimi) richiederebbe un vero ritratto da studio — le foto hero/profilo attuali sono scatti candidi all'aperto, non adatte a quella composizione. Non replicato per questo motivo.
- **Filmstrip in "Lavori selezionati"** (`.filmstrip`): striscia di foto vere (prime 6 miniature di Business & Eventi e di Motorsport, alternate) che scorre da sola in loop continuo, si ferma al passaggio del mouse, rispetta `prefers-reduced-motion`. Serve a mostrare subito il lavoro senza obbligare l'utente a cliccare dentro una galleria — le card sotto restano per chi vuole approfondire, ma la prima impressione è "storytelling", non un click forzato.

## Elementi identitari da preservare

- Grana pellicola su tutta la pagina (SVG noise overlay, opacity 0.055)
- Parentesi "mirino" (`.vf`) su hover di card e lightbox
- Numerazione stile "provino a contatto" (`N°01`, `N°02`...) nelle gallerie
- Kicker monospace maiuscolo con lettere spaziate come firma editoriale ricorrente
