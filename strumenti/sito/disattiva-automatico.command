#!/bin/bash
cd "$(dirname "$0")"
/usr/bin/python3 aggiorna_foto.py --disinstalla
echo
read -n 1 -s -r -p "Premi un tasto per chiudere questa finestra."
