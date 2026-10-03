#!/bin/bash
# Da fare UNA volta: da qui in poi basta mettere/togliere/rinominare foto in FOTO/ e il sito si aggiorna da solo
cd "$(dirname "$0")"
/usr/bin/python3 strumenti/sito/aggiorna_foto.py --installa
echo
read -n 1 -s -r -p "Premi un tasto per chiudere questa finestra."
