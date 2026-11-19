<!--
  README.md
  AriaLite

  Created by Giovanni Michele on 20/11/26.
-->

# AriaLite

App iOS e iPadOS di **AriA**, la piattaforma di manutenzione industriale con assistente AI. Porta sul telefono la
chat con Aria, gli ordini di lavoro e le sezioni della web app, e si adatta a chi entra: il manutentore in campo,
il membro dell'azienda, l'amministratore o il titolare.

## Accesso e account

- **Un solo campo email** per operatori e account della piattaforma: arriva un link di accesso, senza password.
- **Face ID** per riaprire l'app con la sessione salvata.
- **Registrazione nell'app**, in quattro passi: profilo, azienda, sito e piano.
- **Primi passi con AriA**: la guida alla configurazione, nelle impostazioni.
- **Ruoli e diritti**: sezioni, interruttori e pulsanti seguono il ruolo letto da `GET /v1/me`, riletto a ogni
  ritorno in primo piano. Se il ruolo cambia, l'app si aggiorna senza un nuovo accesso.
- **Più aziende e siti**: si sceglie l'azienda e il sito su cui lavorare.

## Chat con Aria

- **Conversazioni** in streaming, con cronologia, ricerca delle sessioni passate e ripresa dopo un'interruzione.
- **Dettatura**: si parla invece di scrivere; il riconoscimento conosce codici allarme, tag e termini dell'azienda.
- **Allegati e contesto**: foto, file, strumenti attivi e l'anello della memoria della conversazione.
- **Connettori** (Composio): si collegano i servizi esterni direttamente dalla chat.
- **Effort**: si sceglie quanto deve ragionare Aria; il costo di ogni risposta in crediti si vede sotto il messaggio.
- **Card interattive**: ordini di lavoro, tabelle, KPI, grafici, asset, piani, diagnostica, allarmi e dashboard.
- **Procedure guidate**: le checklist di Aria si eseguono un passo alla volta, con "Fatto", "Indietro" e la
  richiesta di aiuto sul singolo passo.
- **Domande guidate**: Aria propone risposte da scegliere con un tocco, oppure si risponde liberamente.
- **Approvazioni**: prima di un'azione rischiosa Aria si ferma e chiede conferma; i parametri si possono
  modificare prima di approvare.
- **Conferma LOTO** (lockout/tagout) prima di continuare una procedura.
- **Piani di riassegnazione**: carico delle squadre e spostamenti proposti, da applicare in blocco.
- **Memoria e apprendimento**: Aria propone cosa ricordare; l'operatore lo manda agli amministratori, che lo
  approvano.
- **Chiusura dell'intervento**: dalla chat si crea l'ordine di lavoro con il report allegato, con anteprima
  prima di confermare (e MaintainX se collegato).

## Per i manutentori

- **Task e calendario**: gli ordini di lavoro assegnati, per elenco o per giorno.
- **Esecuzione passo per passo**: "Done" / "Not done" con motivo, note e foto per ogni passo, avanzamento a
  pallini e "Ask AriA" sul passo corrente.
- **Offline**: tutto si salva prima sul telefono e si sincronizza appena torna la rete, con lo stato della
  sincronizzazione sempre visibile.
- **Disponibilità**: l'operatore decide se l'assegnazione automatica gli manda ordini nuovi.
- **Notifiche push** per i lavori assegnati: un tocco apre direttamente il lavoro.

## Per amministratori e membri

Le sezioni della web app, raggruppate come nella sua sidebar. Ognuna compare solo se il ruolo la concede.

| Area | Sezioni |
| --- | --- |
| **Intelligence** | Documenti (caricamento in background, anche ad app chiusa), Agent Studio (workflow, esecuzioni dal vivo, approvazioni, policy, prompt, accuratezza), Marketplace (skill, connettori, plugin, workflow e pacchetti), Extraction Review, Learned knowledge, Scenario analysis, Crafted |
| **Operations** | Work Orders, Maintenance, Inspections, Taskboard |
| **Resources** | Assets, Spare Parts, Alarms |
| **Purchases** | Purchase Orders, Vendors |
| **Analytics** | Reports, LLM Usage (crediti del ciclo, dove sono andati e i controlli di spesa per il titolare) |
| **Configuration** | Sites, Categories, Teams, Users (inviti e accesso all'app), Roles & Rights |

## Esperienza

- **iPhone e iPad**: su iPad le schermate restano a una larghezza leggibile; orizzontale e tastiera sono gestiti.
- **Inglese e italiano**, compreso il catalogo del Marketplace.
- **Dynamic Type** ovunque, VoiceOver e modalità scura.

## Sviluppo

Requisiti: Xcode recente (il progetto è aggiornato con Xcode 27), iOS / iPadOS 18.0 o successivo.

```sh
git clone https://github.com/GiovanniMicheleNapoli23/AriA-LT.git
open AriA-LT/AriaLite/AriaLite.xcodeproj
```

Si avvia lo schema **AriaLite**. Senza configurazione l'app punta ai server di produzione
(`AriaLite/Config/AriaLite.xcconfig`). Per altri host o per la chiave del motore vocale si copia
`Secrets.example.xcconfig` in `Secrets.xcconfig` (ignorato da git) e si scommentano solo le chiavi da cambiare.

Il codice è diviso in `App/`, `Shared/` (backend, login, chat, navigazione), `Maintainer/` e `Admin/` (una
cartella per sezione). Ogni funzionalità segue MVVM: `Model/`, `ViewModel/` (tutta la logica), `Views/` e
`Components/`.

I test sono in `AriaLiteTests` (Swift Testing) e `AriaLiteUITests`. I test UI girano contro il backend vero con
`AriaLite/scripts/ui-tests.sh`.
