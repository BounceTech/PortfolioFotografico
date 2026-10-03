#!/bin/bash
# Aggiorna subito il sito con quello che c'è nella cartella FOTO/ (serve solo se l'automatico è spento)
cd "$(dirname "$0")"
/usr/bin/python3 strumenti/sito/aggiorna_foto.py
echo
read -n 1 -s -r -p "Fatto. Premi un tasto per chiudere questa finestra."
