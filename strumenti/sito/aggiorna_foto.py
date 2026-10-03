#!/usr/bin/env python3
"""
Aggiorna foto — tiene il sito mattiabuoli.it allineato alla cartella FOTO/

La cartella FOTO/ è l'unica fonte: tre cartelle, una per galleria del sito
(Business e eventi · Motorsport · Extra).
  - aggiungi una foto    → compare sul sito
  - cancella una foto    → sparisce dal sito
  - rinomina una foto    → cambia l'ordine (01 …, 02 …, 03 …)

Lo script crea in images/galleria/<galleria>/ la versione web (2400 px) e la
miniatura (800 px), toglie i dati GPS/EXIF e scrive images/gallerie.js, l'elenco
che il sito legge per mostrare le foto nell'ordine giusto.

Uso:
  python3 aggiorna_foto.py              aggiorna e chiede se pubblicare
  python3 aggiorna_foto.py --auto       aggiorna e pubblica da solo (usato dall'automatico)
  python3 aggiorna_foto.py --installa   attiva l'aggiornamento automatico (macOS)
  python3 aggiorna_foto.py --disinstalla
"""
import fcntl, json, os, re, subprocess, sys, time, unicodedata
from xml.sax.saxutils import escape
from datetime import datetime

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FOTO = os.path.join(REPO, 'FOTO')
USCITA = os.path.join(REPO, 'images', 'galleria')
MANIFEST = os.path.join(REPO, 'images', 'gallerie.js')
LOG = os.path.join(REPO, 'strumenti', 'sito', 'automatico.log')
LOCK = os.path.join(REPO, 'strumenti', 'sito', '.aggiorna.lock')
ETICHETTA = 'it.mattiabuoli.foto'
PLIST = os.path.expanduser(f'~/Library/LaunchAgents/{ETICHETTA}.plist')

# id usato dal sito  →  cartella dentro FOTO/ (le uniche tre cartelle previste)
GALLERIE = {
    'business':   'Business e eventi',
    'motorsport': 'Motorsport',
    'extra':      'Extra',
}

LATO_SITO, LATO_THUMB = 2400, 800
ESTENSIONI = ('.jpg', '.jpeg', '.png', '.tif', '.tiff', '.webp')
ORDINE = re.compile(r'^(\d+)[\s._-]*')        # "03 barman.jpg" → posizione 3


def log(msg):
    print(msg, flush=True)


# ---------------------------------------------------------------- lettura FOTO/

def slug(testo):
    testo = unicodedata.normalize('NFKD', testo).encode('ascii', 'ignore').decode()
    return re.sub(r'[^a-zA-Z0-9]+', '-', testo).strip('-').lower()


def chiave_ordine(nome):
    """01 xxx < 2 xxx < 10 xxx < poi i file senza numero, in ordine alfabetico."""
    stem = os.path.splitext(nome)[0]
    m = ORDINE.match(stem)
    return (0, int(m.group(1)), stem.lower()) if m else (1, 0, stem.lower())


def sorgenti(cartella):
    if not os.path.isdir(cartella):
        return []
    nomi = [f for f in os.listdir(cartella)
            if f.lower().endswith(ESTENSIONI) and not f.startswith(('.', '~'))]
    return sorted(nomi, key=chiave_ordine)


def istantanea():
    """Nomi, pesi e date dei file: se non cambiano per qualche secondo la copia è finita."""
    stato = []
    for rel in GALLERIE.values():
        c = os.path.join(FOTO, rel)
        for f in sorgenti(c):
            st = os.stat(os.path.join(c, f))
            stato.append((rel, f, st.st_size, int(st.st_mtime)))
    return stato


def aspetta_copia_finita(massimo=180):
    prima, inizio = istantanea(), time.time()
    while time.time() - inizio < massimo:
        time.sleep(6)
        ora = istantanea()
        if ora == prima:
            return
        prima = ora


# ---------------------------------------------------------------- elaborazione

def converti(src, dest_web, dest_thumb):
    from PIL import Image, ImageOps
    with Image.open(src) as im:
        img = ImageOps.exif_transpose(im).convert('RGB')   # raddrizza, scarta EXIF/GPS
    misure = None
    for lato, dest, q in ((LATO_SITO, dest_web, 84), (LATO_THUMB, dest_thumb, 80)):
        copia = img.copy()
        copia.thumbnail((lato, lato), Image.LANCZOS)
        tmp = dest + '.tmp'
        copia.save(tmp, 'JPEG', quality=q, optimize=True, progressive=True)
        os.replace(tmp, dest)
        misure = misure or copia.size
    return misure


def misure_di(path):
    from PIL import Image
    with Image.open(path) as im:
        return im.size


def cartelle_scollegate():
    """Foto in posti che il sito non legge (altre cartelle, sottocartelle, foto sciolte in FOTO/)."""
    avvisi = []
    for radice, dirs, files in os.walk(FOTO):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        rel = os.path.relpath(radice, FOTO)
        if rel == '.':
            if sorgenti(radice):
                avvisi.append('FOTO (foto fuori dalle tre cartelle)')
        elif rel not in GALLERIE.values() and sorgenti(radice):
            avvisi.append(rel)
    return avvisi


def sincronizza():
    """Allinea images/galleria/ e gallerie.js a FOTO/. Ritorna (modifiche, totali)."""
    try:
        import PIL  # noqa: F401
    except ImportError:
        sys.exit('Manca Pillow. Nel Terminale: /usr/bin/python3 -m pip install --user Pillow')

    modifiche, manifest = [], {}
    for gid, rel in GALLERIE.items():
        src_dir = os.path.join(FOTO, rel)
        out_dir = os.path.join(USCITA, gid)
        os.makedirs(src_dir, exist_ok=True)
        os.makedirs(os.path.join(out_dir, 'thumbs'), exist_ok=True)

        voci, usate = [], set()
        for f in sorgenti(src_dir):
            stem = os.path.splitext(f)[0]
            base = slug(ORDINE.sub('', stem)) or slug(stem) or 'foto'
            chiave, n = base, 2
            while chiave in usate:
                chiave, n = f'{base}-{n}', n + 1

            src = os.path.join(src_dir, f)
            web = os.path.join(out_dir, chiave + '.jpg')
            thumb = os.path.join(out_dir, 'thumbs', chiave + '.jpg')
            nuova = (not os.path.exists(web) or not os.path.exists(thumb)
                     or os.path.getmtime(src) > os.path.getmtime(web))
            try:
                if nuova:
                    w, h = converti(src, web, thumb)
                    modifiche.append(f'+ {rel}/{f}')
                else:
                    w, h = misure_di(web)
            except Exception as e:
                log(f'  ✗ {rel}/{f}: non riesco ad aprirla ({e}) — la salto')
                continue
            usate.add(chiave)
            voci.append({'src': f'images/galleria/{gid}/{chiave}.jpg',
                         'thumb': f'images/galleria/{gid}/thumbs/{chiave}.jpg',
                         'w': w, 'h': h})

        # foto tolte da FOTO/ → via anche dal sito
        for cartella in (out_dir, os.path.join(out_dir, 'thumbs')):
            for f in os.listdir(cartella):
                if f.endswith('.jpg') and os.path.splitext(f)[0] not in usate:
                    os.remove(os.path.join(cartella, f))
                    if cartella == out_dir:
                        modifiche.append(f'- {rel}/{f}')
        manifest[gid] = voci

    # gallerie che non esistono più → via dal sito
    import shutil
    for gid in os.listdir(USCITA):
        if gid not in GALLERIE and os.path.isdir(os.path.join(USCITA, gid)):
            shutil.rmtree(os.path.join(USCITA, gid))
            modifiche.append(f'- galleria {gid}')


    testo = ('// GENERATO DA strumenti/sito/aggiorna_foto.py — non modificare a mano.\n'
             '// Per aggiungere, togliere o riordinare foto lavora nella cartella FOTO/.\n'
             'window.GALLERIE = {\n' + ',\n'.join(
                 f' {json.dumps(g)}: [' + ''.join(f'\n  {json.dumps(v)},' for v in voci).rstrip(',')
                 + ('\n ]' if voci else ']') for g, voci in manifest.items()) + '\n};\n')
    vecchio = open(MANIFEST, encoding='utf-8').read() if os.path.exists(MANIFEST) else ''
    if testo != vecchio:
        open(MANIFEST, 'w', encoding='utf-8').write(testo)
        if not modifiche:
            modifiche.append('~ nuovo ordine delle foto')
    return modifiche, {g: len(v) for g, v in manifest.items()}


# ---------------------------------------------------------------- pubblicazione

def git(*args):
    env = dict(os.environ, GIT_TERMINAL_PROMPT='0')
    return subprocess.run(['git', *args], cwd=REPO, capture_output=True, text=True, env=env)


def pubblica(modifiche):
    percorsi = ['images/galleria', 'images/gallerie.js']
    git('add', '-A', '--', *percorsi)
    if git('diff', '--cached', '--quiet', '--', *percorsi).returncode == 0:
        return True, 'niente da pubblicare'
    riepilogo = ', '.join(modifiche[:3]) + (' …' if len(modifiche) > 3 else '')
    r = git('commit', '-m', f'Foto aggiornate {datetime.now():%d/%m %H:%M}: {riepilogo}', '--', *percorsi)
    if r.returncode != 0:
        return False, (r.stderr or r.stdout).strip()
    r = git('push')
    if r.returncode != 0:                       # il sito online è più avanti: allineo e riprovo
        git('pull', '--rebase', '--autostash')
        r = git('push')
    return r.returncode == 0, (r.stderr or r.stdout).strip()


def notifica(titolo, testo):
    if sys.platform == 'darwin':
        testo = testo.replace('"', "'")
        subprocess.run(['osascript', '-e', f'display notification "{testo}" with title "{titolo}"'],
                       capture_output=True)


# ---------------------------------------------------------------- automatico (macOS)

def installa():
    py = sys.executable
    cartelle = [os.path.join(FOTO, r) for r in GALLERIE.values()]
    for c in cartelle:
        os.makedirs(c, exist_ok=True)
    watch = '\n'.join(f'    <string>{escape(c)}</string>' for c in cartelle)
    plist = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>{ETICHETTA}</string>
  <key>ProgramArguments</key>
  <array>
    <string>{escape(py)}</string>
    <string>{escape(os.path.abspath(__file__))}</string>
    <string>--auto</string>
  </array>
  <key>WatchPaths</key>
  <array>
{watch}
  </array>
  <key>StartInterval</key><integer>1800</integer>
  <key>ThrottleInterval</key><integer>20</integer>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
  <key>StandardOutPath</key><string>{escape(LOG)}</string>
  <key>StandardErrorPath</key><string>{escape(LOG)}</string>
</dict>
</plist>
'''
    os.makedirs(os.path.dirname(PLIST), exist_ok=True)
    uid = str(os.getuid())
    subprocess.run(['launchctl', 'bootout', f'gui/{uid}/{ETICHETTA}'], capture_output=True)
    open(PLIST, 'w').write(plist)
    r = subprocess.run(['launchctl', 'bootstrap', f'gui/{uid}', PLIST], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit('Non riesco ad attivarlo: ' + r.stderr)
    log('✓ Aggiornamento automatico ATTIVO.\n')
    log('  Da ora basta mettere, togliere o rinominare foto dentro FOTO/:')
    log('  entro un minuto il sito si aggiorna e ricevi una notifica.\n')
    log('  Se macOS chiede di consentire l\'accesso alla cartella Documenti, clicca Consenti.')
    log(f'  Se non arriva nessuna notifica, apri {LOG}:')
    log('  con "Operation not permitted" vai in Impostazioni di Sistema › Privacy e sicurezza ›')
    log(f'  Accesso completo al disco › + › aggiungi {py}')


def disinstalla():
    subprocess.run(['launchctl', 'bootout', f'gui/{os.getuid()}/{ETICHETTA}'], capture_output=True)
    if os.path.exists(PLIST):
        os.remove(PLIST)
    log('✓ Aggiornamento automatico disattivato. Puoi sempre usare aggiorna-foto.command.')


# ---------------------------------------------------------------- main

def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else ''
    if arg == '--installa':
        return installa()
    if arg == '--disinstalla':
        return disinstalla()

    auto = arg == '--auto'
    lock = open(LOCK, 'w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        log('Un aggiornamento è già in corso.')
        return

    if auto:
        aspetta_copia_finita()
        log(f'\n[{datetime.now():%d/%m/%Y %H:%M:%S}] controllo FOTO/')

    modifiche, totali = sincronizza()
    for m in modifiche:
        log('  ' + m)
    log('  Foto sul sito: ' + ' · '.join(f'{g} {n}' for g, n in totali.items()))

    avvisi = cartelle_scollegate()
    for a in avvisi:
        log(f'  ⚠ "{a}": quelle foto NON vengono pubblicate.')
    if avvisi:
        log('    Il sito legge solo ' + ', '.join(f'"{c}"' for c in GALLERIE.values())
            + ' (senza sottocartelle): spostale lì dentro.')
        if auto:
            notifica('Sito: foto in una cartella sconosciuta',
                     f'"{avvisi[0]}": le foto non vengono pubblicate')

    if not modifiche:
        if not auto:
            log('\nNessuna novità: il sito è già allineato alla cartella FOTO/.')
        return

    if auto:
        ok, msg = pubblica(modifiche)
        log('  pubblicato' if ok else '  pubblicazione NON riuscita: ' + msg)
        notifica('Sito aggiornato' if ok else 'Sito: pubblicazione non riuscita',
                 f'{len(modifiche)} modifiche alle foto, online in 1-2 minuti' if ok
                 else 'Apri GitHub Desktop e fai Push')
        return

    if input('\nPubblico subito online su mattiabuoli.it? (s/n) ').strip().lower() == 's':
        ok, msg = pubblica(modifiche)
        log('✓ Pubblicato: il sito si aggiorna in 1-2 minuti.' if ok
            else 'Pubblicazione non riuscita, riprova da GitHub Desktop:\n' + msg)
    else:
        log('Ok, non pubblico. Puoi farlo dopo da GitHub Desktop (Commit + Push).')


if __name__ == '__main__':
    main()
