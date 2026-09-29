#!/usr/bin/env python3
# genera.py v2.1 - Mattia Buoli Photo Selection System
# Avvio: python3 genera.py

import hmac as _hmac, hashlib, json, os, re, shutil, subprocess, sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print()
    print("  Pillow non trovato. Installa con: pip install Pillow")
    sys.exit(1)

# -----------------------------------------------------------
WHATSAPP_NUM    = '393348493876'
REPO_DIR        = Path(__file__).resolve().parents[2]   # radice di PortfolioFotografico
GALLERY_DIR     = 'galleriaclienti'
SITO_BASE       = 'https://mattiabuoli.it'
OUTPUT_DIR      = Path(__file__).resolve().parent / 'progetti'

# Segreti in segreti.py (ignorato da git — la repo e' pubblica). Modello: segreti.example.py
try:
    from segreti import TELEGRAM_TOKEN, TELEGRAM_CHAT, MASTER_KEY, GAS_URL
except ImportError:
    print()
    print("  segreti.py non trovato. Copia segreti.example.py in segreti.py e compila i valori.")
    sys.exit(1)

def make_secret(job_name):
    return _hmac.new(MASTER_KEY.encode(), job_name.encode(), hashlib.sha256).hexdigest()[:16]
# -----------------------------------------------------------

IMG_EXTS = {'.jpg', '.jpeg', '.png', '.webp', '.tiff', '.bmp'}
MAX_SIDE = 1600
QUALITY  = 82
MAX_KB   = 450

def clear(): os.system('clear')

def header():
    print()
    print("  +==========================================+")
    print("  | MATTIA BUOLI - Galleria Selezione Foto  |")
    print("  |              v2.1                       |")
    print("  +==========================================+")
    print()

def step_banner(n, tot, titolo):
    clear(); header()
    print("  STEP " + str(n) + " di " + str(tot) + " -- " + titolo)
    print("  " + "-" * 46)
    print()

def ok(msg):   print(); print("  OK  " + msg)
def warn(msg): print("  ATTENZIONE: " + msg)

def ask(prompt, hint=None):
    if hint: print("  (" + hint + ")")
    while True:
        val = input("  > " + prompt + ": ").strip()
        if val: return val
        warn("Campo obbligatorio. Riprova.")

def ask_int(prompt, default=0, hint=None):
    if hint: print("  (" + hint + ")")
    while True:
        val = input("  > " + prompt + f" (default: {default}): ").strip()
        if not val: return default
        try:
            return int(val)
        except ValueError:
            warn("Inserisci un numero intero. Riprova.")

def ask_path():
    print("  Trascina la cartella dal Finder in questa finestra,")
    print("  oppure incolla il percorso a mano.")
    print()
    while True:
        raw = input('  > Percorso cartella foto: ').strip().strip("'").strip('"')
        p = Path(raw).expanduser()
        if not p.exists():
            warn("Cartella non trovata: " + str(p)); print(); continue
        if not p.is_dir():
            warn("Non e' una cartella. Riprova."); print(); continue
        foto = sorted(
            [f for f in p.iterdir()
             if f.is_file()
             and f.suffix.lower() in IMG_EXTS
             and not f.name.startswith('.')],   # ignora file ._macOS
            key=lambda x: x.name.lower()
        )
        if not foto:
            warn("Nessuna foto trovata in quella cartella."); print(); continue
        return p, foto

def html_attr_escape(text):
    return (text.replace('&', '&amp;').replace('"', '&quot;')
                .replace('<', '&lt;').replace('>', '&gt;'))

def pw_encode(text):
    import base64
    return base64.b64encode(text.encode('utf-8')).decode('ascii')

def slugify(text):
    s = text.strip().replace(' ', '_')
    return re.sub(r'[^A-Za-z0-9_-]', '', s)

def fix_orientation(img):
    try:
        exif = img._getexif()
        if exif:
            for o, deg in {3:180, 6:270, 8:90}.items():
                if exif.get(274) == o:
                    return img.rotate(deg, expand=True)
    except Exception:
        pass
    return img

def compress(src, dst):
    img = Image.open(src)
    img = fix_orientation(img)
    img = img.convert("RGB")
    w, h = img.size
    if max(w, h) > MAX_SIDE:
        s = MAX_SIDE / max(w, h)
        img = img.resize((int(w*s), int(h*s)), Image.LANCZOS)
    q = QUALITY
    while True:
        img.save(dst, "JPEG", quality=q, optimize=True, progressive=True)
        if dst.stat().st_size <= MAX_KB * 1024 or q <= 55:
            break
        q -= 5
    kb = dst.stat().st_size // 1024
    print("  " + src.name + " -> " + dst.name + " (" + str(kb) + " KB)")

def git_run(cmd, cwd, ignore_if=None):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        msg = r.stderr.strip() or r.stdout.strip() or "(nessun dettaglio)"
        if ignore_if and ignore_if in msg:
            return msg
        print("  ERRORE git [" + " ".join(cmd) + "]:")
        print("  " + msg)
        sys.exit(1)
    return r.stdout.strip()

def main():
    TOT = 5   # uno step in meno: slug auto-generato

    # STEP 1
    step_banner(1, TOT, "Dove si trovano le foto?")
    foto_dir, foto_files = ask_path()
    ok("Trovate " + str(len(foto_files)) + " foto")
    input("\n  Premi Invio per continuare...")

    # STEP 2
    step_banner(2, TOT, "Chi e' il cliente?")
    cliente = ask("Nome del cliente", hint="es. Luigi Mastroianni")
    ok("Cliente: " + cliente)
    input("\n  Premi Invio per continuare...")

    # STEP 3
    step_banner(3, TOT, "Nome dell'evento / progetto")
    print("  Questo sara' il titolo in cima alla galleria, nel messaggio WhatsApp")
    print("  e nell'URL della pagina web.")
    print()
    print("  Esempi: Battesimo Dario  /  Matrimonio Rossi  /  Compleanno Laura")
    print()
    nome_evento = ask("Nome evento")
    if not re.match(r"^\d{6}_", nome_evento):
        warn("Non sembra nel formato AAMMGG_NomeEvento (es. 260612_Cherimoya).")
        warn("Il riconoscimento automatico delle foto in Lightroom si basa su questo nome:")
        warn("se non e' preciso rischi di non trovare le foto, non di trovare quelle sbagliate.")
        if input("\n  Continuo comunque? [s/N] ").strip().lower() != "s":
            print("\n  Annullato."); sys.exit(0)
    slug    = slugify(nome_evento)
    storage = slug.replace("-", "_")
    ok("Nome evento : " + nome_evento)
    ok("Slug URL    : " + slug)
    ok("Link finale : " + SITO_BASE + "/" + GALLERY_DIR + "/" + slug + "/")
    input("\n  Premi Invio per continuare...")

    # STEP 4
    step_banner(4, TOT, "Limite foto selezionabili")
    print("  Quante foto puo' selezionare il cliente?")
    print("  Scrivi 0 per nessun limite.")
    print()
    max_sel = ask_int("Numero massimo selezioni", default=0)
    if max_sel > 0:
        ok(f"Limite: {max_sel} foto")
    else:
        ok("Nessun limite impostato")
    input("\n  Premi Invio per continuare...")

    # STEP 5
    step_banner(5, TOT, "Password per il cliente")
    print("  Scegli una password da mandare al cliente su WhatsApp.")
    print("  Deve essere semplice da digitare (es. fiori2026, luna, mattia).")
    print()
    password = ask("Password")
    pw_hash  = pw_encode(password)
    ok("Password impostata")
    input("\n  Premi Invio per continuare...")

    # RIEPILOGO
    step_banner("R", TOT, "Riepilogo -- controlla prima di procedere")
    proj_dir = OUTPUT_DIR / slug
    dest     = REPO_DIR / GALLERY_DIR / slug
    link     = SITO_BASE + "/" + GALLERY_DIR + "/" + slug + "/"
    template = Path(__file__).parent / "template.html"
    print("  Cliente      : " + cliente)
    print("  Evento       : " + nome_evento)
    print("  Slug URL     : " + slug)
    print("  Foto         : " + str(len(foto_files)) + " immagini")
    print("  Max selezioni: " + (str(max_sel) if max_sel > 0 else "nessun limite"))
    print("  Link         : " + link)
    print()
    conferma = input('  Tutto ok? Vuoi procedere? [s/N] ').strip().lower()
    if conferma != "s":
        print(); print("  Annullato."); sys.exit(0)

    # ELABORAZIONE
    clear(); header()
    print("  Elaborazione e pubblicazione in corso...")
    print()
    if not template.exists():
        print("  ERRORE: template.html non trovato accanto a genera.py")
        sys.exit(1)

    foto_out = proj_dir / "foto"
    if proj_dir.exists(): shutil.rmtree(proj_dir)
    foto_out.mkdir(parents=True, exist_ok=True)

    print("  Compressione foto in corso...")
    print()
    foto_json = []
    for src in foto_files:
        fname = src.stem + ".jpg"
        dst   = foto_out / fname
        c = 2
        while dst.exists():
            fname = src.stem + "-" + str(c) + ".jpg"; dst = foto_out / fname; c += 1
        compress(src, dst)
        foto_json.append({"id": src.stem, "file": fname, "original_name": src.name})

    total_mb = round(sum(f.stat().st_size for f in foto_out.iterdir()) / 1024 / 1024, 1)
    ok(str(len(foto_files)) + " foto elaborate -- " + str(total_mb) + " MB totali")
    print()

    html = template.read_text(encoding="utf-8")
    replacements = [
        ("{{NOME_EVENTO}}",    nome_evento),
        ("{{MAX_SELEZIONI}}", str(max_sel)),
        ("{{WHATSAPP}}",       WHATSAPP_NUM),
        ("{{STORAGE_KEY}}",    storage),
        ("{{PW_HASH}}",        pw_hash),
        ("{{FOTO_JSON}}",      json.dumps(foto_json, ensure_ascii=False)),
        ("{{TELEGRAM_TOKEN}}", TELEGRAM_TOKEN),
        ("{{TELEGRAM_CHAT}}",  TELEGRAM_CHAT),
        ("{{SECRET_CODE}}",    make_secret(nome_evento)),
        ("{{CLIENTE_DEFAULT}}", html_attr_escape(cliente)),
        ("{{GAS_URL}}",        GAS_URL),
    ]
    for k, v in replacements:
        html = html.replace(k, v)
    (proj_dir / "index.html").write_text(html, encoding="utf-8")

    if not REPO_DIR.exists():
        warn("Repo non trovata in " + str(REPO_DIR))
        warn("La galleria e' pronta localmente in: " + str(proj_dir))
        sys.exit(0)

    print("  Copia nella repo...")
    (REPO_DIR / GALLERY_DIR).mkdir(parents=True, exist_ok=True)
    if dest.exists(): shutil.rmtree(dest)
    shutil.copytree(proj_dir, dest)
    ok("Copiata in repo")
    print()
    print("  Pubblicazione su GitHub...")
    git_run(["git", "add", str(dest)], REPO_DIR)
    git_run(["git", "commit", "-m", "Galleria " + cliente + " (" + slug + ") v2"], REPO_DIR,
            ignore_if="nothing to commit")
    git_run(["git", "push"], REPO_DIR)
    ok("Push completato")
    print()
    print("  " + "-" * 46)
    print()
    print("  TUTTO FATTO!")
    print()
    print("  " + "=" * 46)
    print()
    print("  COPIA E MANDA SU WHATSAPP:")
    print()
    wa_msg = (
        "Ciao " + cliente.split()[0] + "! Ho caricato le tue foto.\n"
        "Scegli le tue preferite aprendo questo link:\n\n"
        + link + "\n\n"
        "Password: *" + password + "*"
    )
    if max_sel > 0:
        wa_msg += f"\n\nPuoi selezionare fino a *{max_sel} foto*."

    sep = "  " + "-" * 46
    print(sep)
    for line in wa_msg.splitlines():
        print("  " + line)
    print(sep)
    print()
    try:
        import subprocess as sp
        proc = sp.Popen(["pbcopy"], stdin=sp.PIPE)
        proc.communicate(wa_msg.encode("utf-8"))
        print("  Messaggio copiato negli appunti! Incollalo direttamente su WhatsApp.")
    except Exception:
        print("  (copia manuale: seleziona il testo tra i trattini)")
    print()

if __name__ == "__main__":
    main()
