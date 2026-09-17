tutti i mini giochi vengono attivati da un blocco apposta posizionato random come un bonus

falling tiles- griglia vuota, sulla linea orizzontale finale in basso una tile secchio si spostasta facendo tousch/click a sinistra o destra della tile secchio. dall'alato vengo create e cadono tot random pezzi di vari colori e valori che cadono verso il basso. il compito del secchio è prenderne il piu possibile con il secchio. ogni volta che il secchio ne tocca una viene distrutta e si aggiungono i punti corrispondenti allo score

memo (MEMO!) - griglia 4x5 (20 carte, 10 coppie, tutti i 10 simboli). Si gira una carta con tap, poi una seconda: se hanno lo stesso sprite restano scoperte e si guadagnano punti fissi (25) con moltiplicatore streak crescente; se sono diverse si ricoprono dopo un breve ritardo e la streak si azzera. Scopo: risolvere tutte le coppie prima dello scadere del timer (45s) per incassare un time bonus. Nessuna penalità sui mismatch di default. Arte dedicata in `love/assets/minigiochi/memo/card_1..10.png` + `icon.png` (icona dello speciale sulla board). Config in `src/config.lua` (chiavi `minigameMemo*`), modulo `src/minigames/memo.lua`.



