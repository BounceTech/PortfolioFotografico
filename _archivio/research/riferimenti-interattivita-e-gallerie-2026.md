# Riferimenti di ispirazione — hero con ritratto integrato e modi freschi di navigare una galleria (2026)

Ricerca reale sul web (settembre 2026), tramite ricerche e visita diretta a siti primari e a fonti curatoriali (Awwwards, studi di design, blog tecnici) con strumenti di web search e web fetch. Ogni osservazione riporta la fonte esatta. Dove il rendering JavaScript/WebGL del sito non era osservabile con lo strumento di fetch usato (restituiva solo markup/testo, non l'aspetto visivo reso), la descrizione visiva è attribuita esplicitamente alla fonte curatoriale (case study dello studio, giuria Awwwards, articolo di settore) invece che a un'osservazione diretta — è dichiarato caso per caso. Nessun dettaglio è inventato: se qualcosa non era verificabile, è segnalato come tale.

**Nota di metodo su "Sultan Karimi":** non è stato possibile risalire in modo indipendente al sito originale del riferimento già visto in conversazione — Behance blocca l'accesso diretto (HTTP 403) e non è emerso un dominio personale verificabile tramite ricerca. Il Filone 1 qui sotto è quindi composto da **altri** esempi reali, verificati singolarmente, nella stessa famiglia stilistica (ritratto + tipografia gigante), come richiesto dal compito — non una riverifica di quel riferimento specifico.

Contesto del sito (mattiabuoli.it, già deciso, non riaperto qui): tema dark "mirino" (#0e0e0e), azzurro primario #6fa3bf + bronzo/heritage secondario #b08a5c, Fraunces (display/corsivo) + Inter (testo) + Space Mono (numerazione tipo contact sheet). Sito statico, un solo file HTML/CSS/JS vanilla, nessun framework, nessun WebGL — deve restare leggero anche su mobile.

---

## Filone 1 — Hero con ritratto integrato nella tipografia gigante

### 1. Hannah Miles — hannahmiles.com (design: Extract Studio)
**Cosa è:** portfolio della fotografa londinese Hannah Miles (menswear/people/commercial), Honorable Mention Awwwards il 16/09/2025 — quindi molto recente.
- **Fonte:** case study dello studio, extract.studio/project/hannah-miles, e pagina giuria awwwards.com/sites/hannah-miles.
- **Come è costruito otticamente:** il nome della fotografa è impostato in un carattere display enorme (Ayer Poster, descritto dallo studio come "androgino", scelto per rappresentare "forza ed eleganza") **posizionato sotto/dietro lo strato di immagini**: le foto scorrono sopra la tipografia gigante, non dentro di essa — quindi non è un ritaglio del soggetto dentro le lettere, ma un layering a due strati (testo fisso in basso, immagini che si muovono sopra). Palette a due colori: crema #F7F5F1 e nero #111111.
- **Interazione:** le didascalie appaiono al passaggio del mouse ("captions pop up on hover"), le immagini si espandono al click; un cursore personalizzato con etichetta accompagna il movimento del mouse; un menu fisso permette di saltare a una categoria senza interrompere lo scroll.
- **Mobile:** la pagina Awwwards mostra screenshot dedicati mobile/tablet a corredo del giudizio; non è stato possibile osservare direttamente il comportamento touch-by-touch, ma la struttura (testo fisso + immagini scrollabili sopra) è per costruzione adattabile: su schermi piccoli la tipografia enorme può semplicemente restare più piccola/meno protagonista senza rompere nulla.
- **Foto necessaria:** non un ritratto ritagliato, ma un buon corpus di immagini editoriali esistenti — nessun asset nuovo necessario per questo pattern specifico.
- **Stack:** Node.js, Sanity CMS, Netlify — niente WebGL.

### 2. Dao for Design — daofor.design/photography
**Fonte:** descritto in framer.com/blog/photography-portfolio-websites (curatela Framer); la visita diretta al sito non ha restituito contenuto visivo osservabile con lo strumento di fetch usato (probabile rendering client-side pesante) — quindi questa scheda riporta la descrizione della fonte curatoriale, non un'osservazione diretta.
- **Descrizione riportata:** "large-scale typography — oversized type in gray or black on a white background" affiancata/sovrapposta alla fotografia nella sezione portfolio fotografico dello studio.
- **Limite dichiarato:** non verificabile de visu con questo metodo se il testo sia dietro, sopra o attorno al soggetto — solo la scala tipografica è confermata dalla fonte.

### 3. Ali Sharaf — alisharaf.com
**Fonte:** stessa curatela Framer (framer.com/blog/photography-portfolio-websites). Art director/designer freelance basato nei Paesi Bassi.
- **Descrizione riportata:** tipografia gigante combinata con elementi ritratto; nella pagina contatti è presente un video-selfie dell'autore.
- **Limite dichiarato:** anche qui la visita diretta non ha reso contenuto visivo osservabile; la relazione esatta testo/foto (z-index, maschera, gradiente) non è confermabile con questo metodo — riportato solo perché la fonte curatoriale lo segnala esplicitamente come combinazione tipografia+ritratto.

### 4. Pavilion Promotional — pavilionpromotional.co.uk
**Fonte:** designshack.net, "30+ Typography Trends for 2025" (osservazione diretta della pagina dell'articolo, non del sito stesso).
- **Tecnica descritta:** testo "cutout"/knockout **senza riempimento di colore**, dove lo strato sottostante (nel loro caso immagini sportive animate) è visibile attraverso la forma delle lettere. È la tecnica opposta/complementare a quella di Hannah Miles: qui l'immagine è **dentro** il testo, non dietro.
- **Rilevanza:** è la controparte tecnica esatta dell'effetto "Sultan Karimi" (foto che riempie le lettere) — utile per capire che esiste una famiglia di due tecniche distinte (testo-dietro-foto vs foto-dentro-testo), non una sola.

### Come si costruisce otticamente l'effetto, in generale (fonti tecniche verificate)
Al di là dei singoli siti, la meccanica CSS di questo genere di hero è documentata da fonti tecniche di riferimento, e conferma che è realizzabile in **puro CSS, senza librerie**:
- **Foto dentro le lettere (knockout/mask text):** `background-clip: text` con `color: transparent` su un elemento di testo che ha come `background` la foto — css-tricks.com/text-blocks-over-image/, cloudinary.com/guides/image-effects/how-to-overlay-text-over-an-image-css, frontendhero.dev/tutorial/mask-text-with-image, ishadeed.com/article/handling-text-over-image-css. Richiede una foto con **buon contrasto e composizione semplice**, perché la leggibilità delle lettere dipende dal contenuto dell'immagine in quel punto.
- **Testo dietro il soggetto ritagliato (z-index semplice):** soggetto con sfondo trasparente (PNG/WebP ritagliato) posizionato con `z-index` maggiore sopra un blocco di testo enorme — nessuna libreria necessaria, ma **richiede una foto ritagliabile bene** (soggetto isolato, sfondo semplice o già rimosso in post-produzione).
- **Fallback mobile:** css-tricks.com/image-under-text segnala esplicitamente che questo pattern necessita di un "fallback accettabile" quando lo spazio si restringe — in pratica, sotto una certa larghezza va quasi sempre sostituito con un impaginato impilato (foto sopra, testo sotto, senza sovrapposizione), altrimenti il testo diventa illeggibile sopra/dentro la foto su schermi piccoli.

---

## Filone 2 — Modi freschi di navigare una galleria fotografica

### 1. Hannah Miles — hannahmiles.com (stesso sito del Filone 1)
- **Meccanismo:** niente griglia-di-copertine → pagina-griglia → lightbox a frecce. Al suo posto: una **"infinite, immersive overview"** (descrizione dello studio) in cui le foto scorrono in modo continuo sopra il nome fisso, con didascalie che appaiono in hover e immagini che si espandono al click; un menu fisso permette di saltare direttamente a una categoria.
- **Mobile/touch:** non osservabile touch-by-touch in prima persona, ma la struttura (scroll continuo + tap per espandere) è per natura compatibile col touch.
- **Complessità:** media — scroll infinito performante richiede attenzione (lazy-load delle immagini, IntersectionObserver), ma è realizzabile in JS vanilla senza librerie pesanti né WebGL.

### 2. ICON x Khaby Lame — khaby.iconmagazine.de
**Fonte:** awwwards.com/sites/icon-x-khaby-lame e models.com (editoriale ICON Italia su Khaby Lame, 2022).
- **Meccanismo:** galleria fotografica **draggabile** (le immagini si trascinano con il mouse/dito per scorrere), integrata in un'esperienza audiovisiva più ampia.
- **Nota sulla recency:** questo progetto risale al 2022, quindi **non rientra nella finestra 2025-2026** richiesta — lo riporto comunque perché serve da contro-esempio onesto di complessità.
- **Complessità reale:** **alta** — la giuria Awwwards e models.com confermano l'uso di **Three.js/WebGL** per oggetti 3D rotanti e animazioni sofisticate. Questo è esattamente il tipo di implementazione che **non** rientra nel vincolo "niente WebGL/three.js, sito statico leggero" di Mattia: va citato come riferimento concettuale (il drag come meccanica di navigazione) ma **non replicato con questo stack**.

### 3. Fotografo eventi Marsiglia ("PUShAUNE") — photographe-freelance-marseille.com
**Fonte:** visita diretta al sito (fetch riuscito, contenuto testuale osservato in prima persona).
- **Meccanismo:** ogni progetto fotografico (es. "Hasta siempre", reportage su una manifestazione) è presentato non con un titolo e basta, ma con una **card di metadati in stile "missione"**: livello di esperienza richiesto, indice di pericolo, difficoltà, "fun factor", range di quota, durata missione, dimensione del team, capacità di carico — un vocabolario giocoso preso in prestito da altri ambiti (avventura/gaming) e applicato al racconto di un reportage fotografico. Le foto stesse sono miniature con pulsante "Agrandir" (ingrandisci) per l'immagine a piena risoluzione; sono elencate anche le specifiche dell'attrezzatura usata (Nikon Z9, obiettivi Nikkor).
- **Mobile:** struttura a griglia flessibile, verosimilmente responsive (non testato touch-by-touch).
- **Complessità:** **bassa** — è puro HTML/CSS con contenuto testuale strutturato, nessun JS complesso necessario. L'unico "costo" non tecnico è editoriale: va scritto un micro-racconto/dato per ogni scatto o progetto.

### 4. Studio Rotate — studiorotate.com
**Fonte:** visita diretta (fetch riuscito). Studio di tecnologia e-commerce (clienti: Rapha, Chilly's, Big Green Egg, Loewe, Sungod, Tracksmith) — **non** un sito fotografico, ma il meccanismo di navigazione è trasferibile.
- **Meccanismo:** cliccando il pulsante "Menu", le anteprime dei progetti si aprono **dentro contenitori circolari** invece che in una griglia rettangolare classica — un modo diverso di rivelare le miniature senza lightbox tradizionale.
- **Complessità:** media — realizzabile con `clip-path: circle()` animato in CSS/JS vanilla, nessuna libreria necessaria.

### 5. TheMcBrideCompany — mcbridedesign.com
**Fonte:** hongkiat.com, "20 Websites with Creative MouseOver Effect" (curatela di terzi; non riverificato visivamente in prima persona con lo strumento di fetch usato — segnalato come tale).
- **Meccanismo descritto:** una foto di paesaggio sfocata si "schiarisce"/metti a fuoco **localmente attorno al cursore**, come se il puntatore fosse uno strumento di messa a fuoco fotografica.
- **Perché è particolarmente rilevante qui:** è concettualmente identico al linguaggio "mirino"/messa a fuoco già scelto per il sito di Mattia — un cursore che agisce da "obiettivo" che rivela nitidezza sarebbe una metafora coerente con l'identità visiva esistente, non un elemento preso a caso da altrove.
- **Complessità stimata:** media — si può ottenere con una maschera CSS (`mask`/`radial-gradient` posizionato via variabili CSS aggiornate da JS al movimento del mouse) sovrapposta a due versioni della stessa immagine (una nitida, una sfocata via `filter: blur()`), senza librerie. Su touch andrebbe adattato: fuoco fisso al centro o al primo tocco, non "a seguire" un dito che nella maggior parte del tempo non è a schermo.

### 6. Tecnica CSS scroll-snap orizzontale a schermo intero
**Fonte:** web.dev/articles/css-scroll-snap, css-tricks.com/practical-css-scroll-snapping, webkit.org/demos/scroll-snap (documentazione tecnica di piattaforma, non un singolo sito con nome).
- **Meccanismo:** ogni foto occupa `100vw`/`100vh` in un contenitore con `scroll-snap-type: x mandatory`; lo scroll (anche touch/swipe) scatta automaticamente da una foto alla successiva, schermo intero, senza JavaScript.
- **Perché è rilevante:** risponde esattamente alla richiesta di un'alternativa "immersiva" al grid+lightbox, **confermata dalla documentazione ufficiale della piattaforma web** (non una moda passeggera) e **nativamente touch-friendly** perché si appoggia allo scroll reale del browser, non a una libreria di gesture.
- **Complessità:** **bassa** — solo CSS (`scroll-snap-type`, `scroll-snap-align`), nessun asset nuovo, funziona su foto già esistenti.

---

## Sintesi: 10 idee concrete, realizzabili in HTML/CSS/JS vanilla

1. **[Hero] — media complessità, asset nuovo consigliato.** Ritratto di Mattia ritagliato (sfondo rimosso in post-produzione) sovrapposto via semplice `z-index` a una parola gigante in Fraunces sfumata in azzurro (es. "OBIETTIVO", "MIRINO", o il claim). È la tecnica più fedele al riferimento "Sultan Karimi" (soggetto in rilievo sopra il testo) e la più semplice da realizzare (nessuna maschera CSS, solo layering) — ma richiede un ritratto dedicato con soggetto isolabile bene, non una foto d'archivio qualsiasi.

2. **[Hero] — bassa/media complessità, nessun asset nuovo obbligatorio (testabile su foto esistenti).** Variante "knockout": usare `background-clip: text` per far intravedere una foto esistente di Mattia (es. mentre scatta, mirino all'occhio) dentro le lettere del claim. Prima di commissionare uno scatto dedicato, si può prototipare con foto già in archivio per capire se il contrasto tiene.

3. **[Hero] — bassa complessità, nessun asset nuovo.** Qualunque soluzione con testo sovrapposto al ritratto DEVE prevedere un fallback mobile esplicito: sotto una soglia di larghezza, passare a un impaginato impilato (foto sopra, testo sotto, zero sovrapposizione) invece di rimpicciolire il tutto — è la raccomandazione esplicita delle fonti tecniche CSS consultate (css-tricks.com/image-under-text), non un'opinione.

4. **[Hero] — media complessità, nessun asset nuovo.** Pattern Hannah Miles adattato: il nome/claim di Mattia in Fraunces enorme resta fisso come sfondo, mentre un nastro orizzontale di 4-6 foto di anteprima (business/eventi + motorsport) scorre sopra, con didascalie che appaiono in hover/tap.

5. **[Hero] — media complessità, nessun asset nuovo.** Piccolo cursore personalizzato che, muovendosi sull'hero, mostra una mini-anteprima fotografica che lo segue (pattern "cursor follow image") — coerente col tema mirino se il cursore viene disegnato come piccolo obiettivo/reticolo.

6. **[Gallerie] — bassa complessità, nessun asset nuovo.** Sostituire grid+lightbox con uno scroll orizzontale a schermo intero (CSS `scroll-snap-type: x mandatory`, una foto = 100vw), con la numerazione N°01/N°24 in Space Mono che avanza — tecnica documentata dalla piattaforma web stessa, nativamente touch-friendly, zero librerie.

7. **[Gallerie] — media complessità, nessun asset nuovo.** Effetto "messa a fuoco al cursore": foto sfocata che si schiarisce localmente dove passa il mouse (due copie della stessa immagine, una nitida una sfocata, rivelate via maschera radiale legata alla posizione del cursore) — riprende esplicitamente il linguaggio "mirino" già scelto, non è un effetto preso a caso. Su touch, il fuoco va reso fisso o attivato al tocco, non "a seguire" un dito assente.

8. **[Gallerie] — bassa complessità, lavoro editoriale extra (non fotografico) richiesto.** Sotto ogni foto o piccolo set di foto, 2-3 righe di dati in Space Mono in stile "contact sheet" (luogo, obiettivo usato, un dettaglio del contesto) invece del solo titolo — versione sobria e non "giocattolosa" del pattern visto sul sito del fotografo di Marsiglia, coerente con l'identità editoriale già scelta.

9. **[Gallerie] — media complessità, nessun asset nuovo.** Al click su una miniatura, apertura non con lightbox classico ma con una transizione a cerchio che si espande dal punto cliccato (`clip-path: circle()` animato) — pattern preso da Studio Rotate, realizzabile in CSS/JS vanilla.

10. **[Gallerie] — evitare.** Il drag-gallery di ICON x Khaby Lame è concettualmente interessante ma **usa Three.js/WebGL**: è l'esempio reale di ciò che NON va replicato con lo stack di Mattia — riportato solo come contro-esempio onesto di complessità, non come idea da realizzare.

---

*Documento di ricerca preparato per supportare la pianificazione del redesign. Le scelte finali su quale idea implementare, priorità e eventuale produzione di nuovi asset fotografici restano in mano al fotografo/cliente e al coordinatore del progetto; questo documento non propone un piano d'azione.*
