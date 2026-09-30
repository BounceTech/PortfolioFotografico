#!/usr/bin/env python3
# genera.py v3 - Mattia Buoli Photo Selection System
#
# Uso normale: l'app "Galleria Clienti" (doppio clic) chiama questo script.
#   python3 genera.py                 wizard da terminale (backup)
#   python3 genera.py --app           legge i parametri JSON da stdin, scrive progresso JSON su stdout
#   python3 genera.py --rigenera DIR --password PW [--cliente NOME] [--pubblica]
#                                     ricostruisce una galleria gia' pubblicata col template attuale

import base64, hashlib, html, json, os, re, secrets, shutil, subprocess, sys, tempfile
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

try:
    from PIL import Image, ImageOps
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError as e:
    print("Libreria mancante (" + e.name + "). Installa con: pip3 install --user Pillow cryptography")
    sys.exit(1)

# -----------------------------------------------------------
WHATSAPP_NUM = '393348493876'
QUI          = Path(__file__).resolve().parent
REPO_DIR     = QUI.parents[1]          # radice di PortfolioFotografico
GALLERY_DIR  = 'galleriaclienti'
SITO_BASE    = 'https://mattiabuoli.it'
TEMPLATE     = QUI / 'template.html'

# Segreti in segreti.py (ignorato da git — la repo e' pubblica). Modello: segreti.example.py
sys.path.insert(0, str(QUI))
try:
    from segreti import GAS_URL
except ImportError:
    print("segreti.py non trovato. Copia segreti.example.py in segreti.py e compila i valori.")
    sys.exit(1)
# -----------------------------------------------------------

IMG_EXTS    = {'.jpg', '.jpeg', '.png', '.webp', '.tiff', '.tif', '.bmp'}
MAX_SIDE    = 1600
QUALITY     = 82
MAX_KB      = 450
PBKDF2_ITER = 200_000   # deve restare ragionevole anche sui telefoni (decifra il browser)
FORMATO_JOB = re.compile(r'^\d{6}_')


def slugify(text):
    return re.sub(r'[^A-Za-z0-9_-]', '', text.strip().replace(' ', '_'))


def trova_foto(cartella):
    return sorted((f for f in Path(cartella).iterdir()
                   if f.is_file() and f.suffix.lower() in IMG_EXTS and not f.name.startswith('.')),
                  key=lambda f: f.name.lower())


def compress(src, dst):
    """Ridimensiona a MAX_SIDE e comprime sotto MAX_KB. Nessun EXIF in uscita (niente GPS/dati camera)."""
    with Image.open(src) as im:
        icc = im.info.get('icc_profile')
        img = ImageOps.exif_transpose(im).convert('RGB')
    img.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
    q = QUALITY
    while True:
        img.save(dst, 'JPEG', quality=q, optimize=True, progressive=True, icc_profile=icc)
        if os.path.getsize(dst) <= MAX_KB * 1024 or q <= 55:
            return
        q -= 5


def cifra_vault(password, dati):
    """PBKDF2-SHA256 + AES-256-GCM: stesso schema che il template decifra con WebCrypto."""
    salt, iv = secrets.token_bytes(16), secrets.token_bytes(12)
    key = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, PBKDF2_ITER, 32)
    data = AESGCM(key).encrypt(iv, json.dumps(dati, ensure_ascii=False).encode('utf-8'), None)
    b64 = lambda b: base64.b64encode(b).decode('ascii')
    return {'salt': b64(salt), 'iv': b64(iv), 'iter': PBKDF2_ITER, 'data': b64(data)}


def apri_vault(vault, password):
    key = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), base64.b64decode(vault['salt']), vault['iter'], 32)
    plain = AESGCM(key).decrypt(base64.b64decode(vault['iv']), base64.b64decode(vault['data']), None)
    return json.loads(plain)


def render_html(nome_evento, cliente, password, max_sel, foto_json, storage_key=None):
    config = {
        'nomeEvento':   nome_evento,
        'maxSelezioni': max_sel,
        'whatsapp':     WHATSAPP_NUM,
        'storageKey':   storage_key or slugify(nome_evento).replace('-', '_'),
        'vault':        cifra_vault(password, {
            'foto':    foto_json,
            'cliente': cliente,
            'gasUrl':  GAS_URL,
        }),
    }
    # "</" non deve mai chiudere lo <script> che contiene il JSON
    config_js = json.dumps(config, ensure_ascii=False).replace('</', '<\\/')
    return (TEMPLATE.read_text(encoding='utf-8')
            .replace('{{CONFIG_JSON}}', config_js)
            .replace('{{NOME_EVENTO}}', html.escape(nome_evento)))


def git(*args):
    r = subprocess.run(['git', *args], cwd=REPO_DIR, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError('git ' + args[0] + ': ' + (r.stderr.strip() or r.stdout.strip()))
    return r.stdout.strip()


def pubblica(percorsi, messaggio):
    """Commit solo dei percorsi indicati (mai altri file della repo) e push."""
    rel = [str(Path(p).relative_to(REPO_DIR)) for p in percorsi]
    git('add', '-A', '--', *rel)
    if not git('diff', '--cached', '--name-only', '--', *rel):
        return
    git('commit', '-m', messaggio, '--', *rel)
    try:
        git('push')
    except RuntimeError:
        git('pull', '--rebase', '--autostash')
        git('push')


def messaggio_whatsapp(cliente, link, password, max_sel):
    msg = ('Ciao ' + cliente.split()[0] + '! Ho caricato le tue foto.\n'
           'Scegli le tue preferite aprendo questo link:\n\n' + link + '\n\n'
           'Password: *' + password + '*')
    if max_sel > 0:
        msg += '\n\nPuoi selezionare fino a *' + str(max_sel) + ' foto*.'
    return msg


def copia_appunti(testo):
    try:
        subprocess.run(['pbcopy'], input=testo.encode('utf-8'), check=True)
        return True
    except Exception:
        return False


def crea_galleria(cartella, cliente, nome_evento, password, max_sel=0, avanza=lambda *a: None):
    """Comprime, genera, pubblica. avanza(fase, fatto, totale) riceve il progresso."""
    cliente, nome_evento, password = cliente.strip(), nome_evento.strip(), password.strip()
    if not (cliente and nome_evento and password):
        raise ValueError('Cliente, nome evento e password sono obbligatori.')
    foto = trova_foto(cartella)
    if not foto:
        raise ValueError('Nessuna foto trovata in ' + str(cartella))

    slug = slugify(nome_evento)
    dest = REPO_DIR / GALLERY_DIR / slug
    link = SITO_BASE + '/' + GALLERY_DIR + '/' + slug + '/'

    # Si lavora in una cartella temporanea: la galleria pubblicata viene sostituita solo a lavoro finito
    tmp = Path(tempfile.mkdtemp(prefix='galleria_'))
    try:
        (tmp / 'foto').mkdir()
        foto_json, lavori, usati = [], [], set()
        for src in foto:
            fname, c = src.stem + '.jpg', 2
            while fname.lower() in usati:
                fname, c = src.stem + '-' + str(c) + '.jpg', c + 1
            usati.add(fname.lower())
            foto_json.append({'id': src.stem, 'file': fname, 'original_name': src.name})
            lavori.append((src, tmp / 'foto' / fname))

        avanza('Compressione foto', 0, len(lavori))
        with ProcessPoolExecutor() as ex:
            futuri = [ex.submit(compress, s, d) for s, d in lavori]
            for i, f in enumerate(as_completed(futuri), 1):
                f.result()
                avanza('Compressione foto', i, len(lavori))

        (tmp / 'index.html').write_text(render_html(nome_evento, cliente, password, max_sel, foto_json),
                                        encoding='utf-8')
        avanza('Pubblicazione', 0, 1)
        if dest.exists():
            shutil.rmtree(dest)
        shutil.move(str(tmp), str(dest))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    pubblica([dest], 'Galleria ' + cliente + ' (' + slug + ')')
    avanza('Pubblicazione', 1, 1)
    msg = messaggio_whatsapp(cliente, link, password, max_sel)
    copia_appunti(msg)
    return {'link': link, 'messaggio': msg, 'foto': len(foto)}


# ---------- rigenerazione gallerie gia' pubblicate ----------

def leggi_galleria(cartella, password):
    """Riapre una galleria pubblicata (serve la sua password: i dati sono nel vault cifrato)."""
    h = (Path(cartella) / 'index.html').read_text(encoding='utf-8')
    cfg = json.loads(re.search(r'const CONFIG = (\{.*?\});\n', h)[1])
    try:
        dati = apri_vault(cfg['vault'], password)
    except Exception:
        raise ValueError('password sbagliata per ' + Path(cartella).name)
    return {
        'nome_evento': cfg['nomeEvento'],
        'storage_key': cfg['storageKey'],
        'max_sel':     cfg['maxSelezioni'],
        # gallerie precedenti: il nome stava nel campo di login
        'cliente':     dati.get('cliente') or html.unescape((re.search(r'id="name-input"[^>]*value="([^"]*)"', h) or ['', ''])[1]),
        'password':    password,
        'foto':        dati['foto'],
    }


def rigenera(cartella, password, cliente=None):
    c = Path(cartella).resolve()
    d = leggi_galleria(c, password)
    (c / 'index.html').write_text(render_html(d['nome_evento'], cliente or d['cliente'], d['password'],
                                              d['max_sel'], d['foto'], d['storage_key']), encoding='utf-8')
    print('OK  ' + c.name + '  (' + str(len(d['foto'])) + ' foto)')
    return c


# ---------- modalita' app (JSON su stdin/stdout) ----------

def main_app():
    def emetti(**kw):
        print(json.dumps(kw, ensure_ascii=False), flush=True)
    try:
        p = json.load(sys.stdin)
        r = crea_galleria(p['cartella'], p['cliente'], p['evento'], p['password'], int(p.get('max') or 0),
                          avanza=lambda fase, fatto, tot: emetti(tipo='progresso', fase=fase, fatto=fatto, totale=tot))
        emetti(tipo='fine', **r)
    except Exception as e:
        emetti(tipo='errore', testo=str(e))
        sys.exit(1)


# ---------- wizard da terminale (backup) ----------

def main_terminale():
    def chiedi(prompt, default=''):
        while True:
            v = input('  > ' + prompt + (' [' + default + ']' if default else '') + ': ').strip() or default
            if v: return v

    print('\n  MATTIA BUOLI - Galleria Selezione Foto v3\n')
    while True:
        cartella = Path(chiedi('Cartella foto (trascinala qui)').strip('\'"')).expanduser()
        if cartella.is_dir() and trova_foto(cartella): break
        print('  Nessuna foto trovata in quella cartella.')
    print('  ' + str(len(trova_foto(cartella))) + ' foto')
    evento = chiedi('Nome evento (AAMMGG_NomeEvento)', cartella.name)
    if not FORMATO_JOB.match(evento):
        print('  ATTENZIONE: senza il formato AAMMGG_ il plugin di Lightroom non trova le foto.')
    cliente = chiedi('Nome cliente')
    password = chiedi('Password')
    max_sel = int(chiedi('Max selezioni (0 = nessun limite)', '0'))

    def avanza(fase, fatto, tot):
        print('\r  ' + fase + ': ' + str(fatto) + '/' + str(tot) + '   ', end='' if fatto < tot else '\n', flush=True)
    r = crea_galleria(cartella, cliente, evento, password, max_sel, avanza)
    print('\n' + r['messaggio'] + '\n\n  (messaggio copiato negli appunti)\n')


if __name__ == '__main__':
    if '--app' in sys.argv:
        main_app()
    elif '--rigenera' in sys.argv:
        arg = lambda k: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else None
        c = rigenera(arg('--rigenera'), arg('--password'), arg('--cliente'))
        if '--pubblica' in sys.argv:
            pubblica([c], 'Galleria rigenerata (' + c.name + ')')
    else:
        main_terminale()
