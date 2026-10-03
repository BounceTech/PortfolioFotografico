# Come gestire le foto del sito

**La cartella `FOTO/` è il sito.** Contiene solo tre cartelle, una per ogni galleria. Le foto compaiono online nello stesso ordine.

```
FOTO/
├── Business e eventi/   aziende, eventi, catering, locali
├── Motorsport/          auto, moto, team, eventi del motore
└── Extra/               lavori occasionali: ritratti, squadre sportive…
```

## Aggiungere, togliere, riordinare

| Vuoi… | Fai così |
|---|---|
| **aggiungere** una foto | trascinala nella cartella giusta |
| **toglierla** dal sito | cancellala dalla cartella |
| **spostarla** di galleria | spostala in un'altra cartella |
| **cambiare l'ordine** | rinomina con un numero davanti: `01 Bancone.jpg`, `02 Artigianato.jpg`, `03 …` |
| cambiare la **didascalia** | è il nome del file senza numero: `05 Su strada.jpg` sul sito diventa **N°05 — Su strada** |
| scegliere la **copertina** della galleria | è sempre la prima foto: dalle il numero più basso (meglio una verticale) |

- Le foto con il numero vanno per prime, in ordine di numero (`2` viene prima di `10`). Quelle senza numero vanno in coda, in ordine alfabetico.
- Per infilare una foto tra la `03` e la `04` chiamala `03b …`, oppure rinumera.
- Il nome dopo il numero è la didascalia che si vede sul sito: scrivilo breve e come lo vuoi leggere (`Ristorazione`, `In curva`, `Auto d'epoca`). Se il file ha un nome automatico (`IMG_1234`) la foto resta senza didascalia, solo con il numero.
- Nella pagina della galleria, la foto grande in alto è **la prima foto orizzontale** della cartella.
- In home, "Lavori selezionati" mostra le foto **dalla 2 alla 5 di Business e eventi** e **dalla 2 alla 4 di Motorsport** (la 1 è già la copertina). Per cambiarle, cambia l'ordine.
- **Extra** è la galleria secondaria: in home non ha una card grande ma una riga più discreta sotto le due specialità, con le sue prime 3 foto come miniature.

**Solo quelle tre cartelle vanno online.** Se metti foto in una sottocartella, in una cartella nuova o sciolte in `FOTO/`, quelle foto non vengono pubblicate e ricevi un avviso. Una galleria nuova sul sito va creata insieme a Claude.

## Foto fisse: copertina, ritratto, anteprima

Stanno in `images/sito/`. Per cambiarne una, sostituisci il file **tenendo lo stesso nome**:

| File | Dove si vede |
|---|---|
| `hero-cutout.webp` e `hero-cutout.png` | la tua figura scontornata in apertura, davanti alla scritta BUOLI (servono tutte e due: per cambiarla chiedi a Claude) |
| `profile.jpg` | la foto nella sezione "Chi sono" |
| `og-cover.jpg` | l'anteprima quando mandi il link su WhatsApp o sui social (1200×630) |

## Una volta sola: accendi l'automatico

1. Doppio clic su **`attiva-automatico.command`**. La prima volta: tasto destro › **Apri** › **Apri**.
2. Se macOS chiede l'accesso alla cartella Documenti, clicca **Consenti**.

Da quel momento, ogni volta che cambi qualcosa in `FOTO/`, entro circa un minuto:

- il Mac prepara le foto (versione web 2400 px e miniatura 800 px, senza dati GPS);
- le pubblica su mattiabuoli.it;
- ti arriva la notifica **"Sito aggiornato"**.

Se stai copiando tante foto, aspetta che la copia finisca: lo script aspetta da solo che la cartella smetta di cambiare.

Per spegnerlo: `strumenti/sito/disattiva-automatico.command`.
Per aggiornare a mano, anche con l'automatico spento: doppio clic su **`aggiorna-foto.command`**.

### Se non arriva la notifica

Apri `strumenti/sito/automatico.log`.

- **"Operation not permitted":** vai in Impostazioni di Sistema › Privacy e sicurezza › Accesso completo al disco › **+** e aggiungi Python. Il percorso esatto te lo mostra `attiva-automatico.command`.
- **"pubblicazione NON riuscita":** apri GitHub Desktop e fai Push.

---

## Mappa del progetto

```
PortfolioFotografico/
├── FOTO/                       ← le tue foto: l'unica cartella da toccare (non va su GitHub)
├── COME-AGGIUNGERE-FOTO.md     ← questa guida
├── attiva-automatico.command   ← una volta sola
├── aggiorna-foto.command       ← aggiornamento a mano
│
├── index.html                  ← il sito
├── 404.html, CNAME             ← file tecnici, non toccare
├── images/                     ← galleria/ e gallerie.js sono GENERATI da FOTO/; sito/ = foto fisse
├── galleriaclienti/            ← gallerie private dei clienti (app Galleria Clienti)
├── strumenti/
│   ├── galleriaclienti/        ← app e script delle gallerie clienti
│   └── sito/                   ← motore delle foto (aggiorna_foto.py) e design-system.md
├── _design/tavole/             ← tavole del redesign in PDF (solo sul Mac)
└── _archivio/                  ← prove, ricerche, vecchie istruzioni
```

`FOTO/` non va su GitHub, perché lì metti anche file pesanti. Online vanno solo le versioni leggere in `images/galleria/`. Gli originali restano sul Mac e in Lightroom.
