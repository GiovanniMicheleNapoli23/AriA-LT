<!-- Created by Giovanni Michele on 19/10/26. -->

# AriaPLT Mobile: handover per la versione Android

Questo documento racconta cosa fa oggi l'app iOS (AriaLite) dopo il login e cosa è cambiato negli ultimi commit,
con i contratti col backend che servono a chi costruisce la versione Android.

- **Riferimento:** branch `main`, commit `0157d72` (19/10/2026) più l'albero di lavoro non ancora committato.
- **Fonte:** il codice in `AriaLite/AriaLite/` e i test in `AriaLite/AriaLiteTests/`. Ogni contratto qui sotto è
  stato riletto dal codice o dal backend il 19/10/2026. Quello che **non** ho potuto verificare è marcato
  *non verificato* e raccolto in fondo (sezione 13).
- **Lingua dei messaggi del codice:** i commenti sono in italiano, le stringhe dell'interfaccia in inglese con
  traduzione italiana.

Come leggere lo stato: **[committato]** è in `main`; **[in lavorazione]** è nell'albero di lavoro, scritto ma
non committato (la sync offline, sezione 7).

---

## 1. Cos'è l'app

AriaPLT Mobile è l'app dell'**operatore di manutenzione**. Un operatore è un utente che l'amministratore
dell'azienda invita dal desktop (`mobile-users` nella web app) e che entra **senza password**, con un link via
email. Quello che fa dopo il login:

1. **Task**: vede i lavori (work order) assegnati a lui, divisi in Oggi / In arrivo / Passati.
2. **Dettaglio e esecuzione**: apre un lavoro e lo esegue **un passo alla volta**: segna ogni passo fatto o non
   fatto, aggiunge una nota e fino a 3 foto, e alla fine chiude il lavoro con le note di chiusura.
3. **Calendario**: un mese con un puntino per ogni lavoro.
4. **Chat con Aria**: assistente in streaming (stesso backend della web), anche dentro un passo
   («Ask AriA» sul passo corrente), con domande guidate, checklist di procedura, approvazioni e voce.
5. **Disponibilità**: dice se l'assegnazione automatica può mandargli lavori nuovi.
6. **Notifiche push** per i lavori assegnati.
7. **Offline** (in lavorazione): si lavora anche senza rete; le modifiche partono in coda.

Struttura di navigazione: la chat è la schermata principale; Task, Calendario e Chat (storico) stanno in una
**sidebar** che si apre dal pulsante ☰ o trascinando dal bordo sinistro. In fondo alla sidebar: profilo,
impostazioni e «New chat».

---

## 2. Cosa è cambiato negli ultimi commit

| Commit | Data | Cosa contiene |
|---|---|---|
| `ae7791b` safety steps and dynamic island fix | 28/09 | Chat: gate di sicurezza (il testo del verdetto arriva in un solo pezzo, l'app lo «scrive» a fette), dettatura riscritta (riconoscimento sul telefono + Whisper sul backend), avviso di Real-time Learning dall'isola. |
| `a936fb1` prepare deeplink and fix login | 08/10 | Nuovo accesso con link via email (sezione 4), blocco con Face ID, lista dei lavori e disponibilità, avviso «offline», modelli dei work order, entitlement dei link universali. |
| `de0d5fd` implement new login | 15/10 | Backend riorganizzato in `Auth/`, `Chat/`, `Networking/`, `WorkOrders/`. API dei passi, foto e completamento. `AriaURLPolicy`. Rimosso Turnstile (captcha). Schema condiviso e `.gitignore`. |
| `93148b6` api for chat | 16/10 | Chat per l'operatore: rotte `/v1/mobile/*` (sezione 9) e guardie sulle azioni che un operatore non può fare. |
| `9c3d822` merge PR #2 safetyStep-fix | 16/10 | Merge del ramo dei passi di sicurezza. |
| `0157d72` refactor | 19/10 | Rimosso tutto il codice demo/mock (Overview, Maintenance, Report, Demo, MockData, motore finto, modello locale). **Aggiunti:** notifiche push, salvataggio dei progressi delle checklist, calendario, testo formattato (descrizione e note), testo dei passi, scelta della sorgente foto, dettaglio e runner dei passi ridisegnati, chiusura guidata, menu «···» della chat. |

**Albero di lavoro [in lavorazione], non ancora committato**

- **Sync offline local-first** (sezione 7): database locale, coda delle modifiche, monitor di rete, pillola di
  stato della sincronizzazione, anteprima foto.
- Cache dei risultati del parsing Markdown della chat (5,6 ms → ~0 per testo già visto).
- Barra del pulsante «Continue/Start» nel dettaglio, ora flottante in vetro (solo estetica iOS 26).
- Rimozione di codice provato morto e correzione di test fragili (310 test, 28 suite, tutti verdi al 19/10).

---

## 3. Architettura e configurazione

### Host

| Cosa | Host (produzione) | Chiave di configurazione iOS |
|---|---|---|
| Dati (FastAPI `aria-backend`) | `https://api.ariaplt.com` | `ARIA_API_HOST` → `AriaAPIHost` |
| Accesso, token di sessione, web app (`aria-web`, Next.js) | `https://app.ariaplt.com` | `ARIA_WEB_HOST` → `AriaWebHost` |
| Motore vocale | `https://api.sinaura-group.com` | `ARIA_VOICE_ENGINE_HOST`, `ARIA_VOICE_ENGINE_KEY` |

- Gli host sono **solo il nome** (niente `https://`): l'app costruisce sempre `https://<host>` e rifiuta schema,
  porta, percorso o credenziali. Se mancano o non sono validi valgono quelli di produzione.
- I valori non segreti stanno in `Config/AriaLite.xcconfig`; quelli locali in `Config/Secrets.xcconfig`
  (ignorato da git, modello in `Secrets.example.xcconfig`). Su Android l'equivalente naturale è `BuildConfig`
  per variante.
- I server si cambiano a mano **solo nelle build di debug**.

### Header di ogni chiamata all'API dati

| Header | Valore |
|---|---|
| `Authorization` | `Bearer <JWT>` (sezione 4) |
| `Company-Id` | l'id azienda; **assente** solo su `GET /v1/companies` |
| `Accept-Language` | `it` o `en` (italiano se la lingua del telefono è italiano, altrimenti inglese) |
| `X-Aria-Client` | `aria-ios/<versione>`: solo diagnostica |
| `User-Agent` | `AriaPLT-Mobile/<versione> (iOS <versione os>; <modello>)`: **è il nome del dispositivo** nell'elenco sessioni che vede l'admin. Su Android: `AriaPLT-Mobile/<v> (Android <v>; <modello>)`. |
| `Accept` | `application/json` (o `text/event-stream` per la chat) |

Regole di rete da replicare:

- **Mai cookie.** Tutte le sessioni HTTP sono senza cookie; vale solo l'header `Authorization`.
- **Limite WAF di 8000 byte** sui body JSON (CloudFront davanti all'API): l'app rifiuta in locale un body più
  grande con l'errore `bodyTooLarge`. Non vale per l'upload multipart dell'audio né per l'upload delle foto su S3.
- Un `403` con `Server: cloudfront` è il firewall (`wafBlocked`), non un errore dell'API.
- **Timeout dello stream:** 180 s di silenzio massimo; 30 min di durata massima.
- Un solo **retry su 401**: si invalida il JWT, se ne conia uno nuovo e si ripete la chiamata una volta.

### Politica degli URL (`AriaURLPolicy`)

Gli URL che arrivano dal modello o dal server si aprono solo se `https`/`http` con host, o `mailto`. **Mai**
`tel:`, `sms:`, `aria://`, file locali. Le immagini si scaricano solo da `https`.

---

## 4. Accesso (login senza password)

### Flusso

```
1. POST {auth}/api/auth/mobile/request-link  {"email": "..."}      → 202 {}   (sempre, anche per un'email sconosciuta)
2. L'operatore riceve l'email con   https://app.ariaplt.com/m/sign-in#token=<token>
3. POST {auth}/api/auth/mobile/verify        {"token": "..."}       → 200 {"token", "user": {id, name, email}}
                                                                       + header  set-auth-token: <sessione>
4. GET  {auth}/api/aria/token                Authorization: Bearer <sessione>   → {"token": "<JWT>"}
5. GET  {api}/v1/companies  → azienda, poi  GET {api}/v1/mobile/plants
```

- Il token del link sta nel **frammento** dell'URL (`#token=`), non nella query: il server non lo vede. Vale
  **una volta** e **15 minuti**. La pagina `/m/sign-in` non legge il frammento, quindi aprirla in un browser **non
  consuma** il link.
- La **sessione** (`set-auth-token`, uguale al `token` del body) dura 7 giorni; il server la può riemettere nello
  header `set-auth-token` di `/api/aria/token`: l'app la sostituisce.
- Il **JWT** dura 15 minuti. L'app lo rinnova a **13 minuti** dal conio, misurati con un orologio monotono (l'ora
  del telefono può essere sbagliata), **un rinnovo alla volta** (le chiamate in parallelo aspettano lo stesso).
- **Fine sessione:** `401`/`403` su `/api/aria/token` = sessione finita (scaduta, operatore disabilitato, o un terzo
  dispositivo ha scalzato questo) → si cancella tutto e si torna al login.
- **Al massimo 2 dispositivi per account:** il terzo accesso fa uscire il più vecchio.
- `POST {auth}/api/auth/sign-out` con la sessione chiude **solo questo dispositivo**.
- **Rate limit:** `request-link` 10 ogni 10 minuti, `verify` 10 al minuto; la risposta `429` può avere l'header
  `X-Retry-After` (secondi).
- Un host che risponde `502/503/504` **non** è «link sbagliato» né «sessione finita»: l'app dice «server offline»
  e non slogga.

### Errori del login

| Risposta | Significato nell'app |
|---|---|
| `401` + `code: INVALID_OR_EXPIRED_LINK` | link già usato o scaduto: chiedine uno nuovo |
| `403` + `code: ACCOUNT_DISABLED` | account disattivato: parlane con l'amministratore |
| `404` sulle rotte di accesso | l'host non è quello giusto (`linkSignInUnavailable`) |
| `429` | troppi tentativi (con o senza `X-Retry-After`) |
| `403` + `code: not_a_mobile_user` | il login è valido ma l'utente non è un operatore mobile |

I codici si leggono da `{"code": …}`, oppure annidati in `detail.code` o `error.code`.

### Regole di sicurezza da non perdere (scritte per l'iOS, valgono ovunque)

1. **Il link vale solo se l'accesso è stato chiesto da questo dispositivo.** L'app salva l'email richiesta e l'ora
   (`aria.magic_link_email`, `aria.magic_link_sent_at`) e accetta un link solo **entro 15 minuti**. Senza una
   richiesta pendente rifiuta **senza chiamare il server** (il token non si consuma): errore `noPendingRequest`.
2. **L'email verificata deve coincidere** con quella richiesta (trim + minuscolo). Se è diversa, la sessione appena
   aperta si chiude sul server e l'errore è `accountMismatch`. Motivo: `aria://` lo può aprire chiunque; senza
   questi controlli un link con il token di un altro account farebbe entrare l'operatore nell'account di chi lo manda.
3. Un operatore senza aziende (`GET /v1/companies` vuoto) = membership non più attiva: si scarta la sessione.
4. Un `403` con `detail == "Not a member of this company"` su una chiamata dati = operatore disabilitato a
   sessione aperta: si scarta la sessione e si torna al login. **Gli altri 403 rifiutano solo quell'azione e non
   sloggano.**
5. **Reinstallazione:** il Keychain iOS sopravvive alla disinstallazione, UserDefaults no. Un marcatore
   (`aria.install_marker`) in UserDefaults dice se è la stessa installazione; senza, le credenziali rimaste si
   cancellano. Su Android le chiavi di Keystore e le preferenze cifrate vengono rimosse alla disinstallazione, ma
   con l'Auto Backup si possono ripristinare: *suggerimento:* `allowBackup="false"` (o esclusioni esplicite).

### Come entra il link nell'app

L'app riconosce due forme (`AriaAuth.signInLink(from:)`):

- `https://<host di accesso>/m/sign-in#token=<token>`: l'host deve essere **esattamente** quello di accesso e il
  percorso **esattamente** `/m/sign-in`;
- `aria://sign-in#token=<token>`.

Il token si legge dal frammento; per tolleranza anche da `?token=`. Dal testo incollato (il flusso di riserva) si
estrae il primo URL riconosciuto.

**Android:**

- App Links: filtro di intent `https://app.ariaplt.com/m/sign-in` con `autoVerify`, più lo schema `aria://sign-in`;
  il frammento si legge da `intent.data?.fragment`.
- **Lato server non è ancora pronto** (verificato il 19/10): `https://app.ariaplt.com/.well-known/assetlinks.json`
  risponde **404**. In `aria-web` il file esce solo se sono impostate le variabili `MOBILE_ANDROID_PACKAGE` e
  `MOBILE_ANDROID_CERT_SHA256` (fingerprint SHA-256, anche di debug, separati da virgola; vedi `lib/app-links.ts` e
  `.env.example`). Finché non ci sono il link si apre nel browser e resta il flusso «copia dall'email e incolla».
- Lo stesso vale per iOS: l'AASA pubblicato rivendica ancora solo il vecchio magic link; serve
  `MOBILE_IOS_APP_IDS=4TP9VJ2S7B.com.giovanniMichele.AriaLite`.

### Blocco con la biometria

- La sessione è salvata **protetta**: per leggerla serve Face ID/impronta o il codice del telefono (iOS:
  `.userPresence`). Se il telefono non ha un codice, la protezione non si può creare e il valore si salva
  comunque, ma l'app non si blocca.
- Stati (`SessionLock`): `launch` (avvio con sessione salvata: **la shell non si costruisce** finché non si
  sblocca), `resume` (ritorno dal background: l'app resta sotto, coperta da una finestra). Il prompt parte da solo
  **una volta per chiusura**; dopo un annullamento resta il pulsante. «Use another account» esce e torna al login.
- Annullare il prompt non è un errore da mostrare.
- Android: `BiometricPrompt` + chiave in Keystore con autenticazione richiesta.

---

## 5. Dopo il login: schermate e regole

### 5.1 Avvio (bootstrap)

1. `GET /v1/companies` (senza `Company-Id`) → `[{id, name, myRole}]`. Un operatore ne ha una (`myRole: member`).
   Se ce ne fossero più d'una: quella salvata, altrimenti la prima di cui è `owner`, altrimenti la prima.
2. `GET /v1/mobile/plants` → `[{id, name, code, location}]`. Lo stabilimento attivo è quello salvato, altrimenti
   il primo. Se l'elenco non si legge, i lavori funzionano lo stesso (non servono lo stabilimento) ma la chat no:
   **`plant_id` è obbligatorio** nel body della chat (422 senza).
3. Dentro la shell, a ogni apertura e a ogni ritorno in primo piano: si chiede il permesso push e si registra il
   token (sezione 8), si lancia la sincronizzazione dei lavori (sezione 7) e si azzera il badge.

### 5.2 Task (lista)

- **Oggi:** lavori aperti con scadenza (`dueDate`) **prima della fine di oggi**, quindi anche scaduti **e senza
  scadenza**. **In arrivo:** aperti con scadenza da domani in poi. **Passati:** chiusi (`completed`, `verified`,
  `cancelled`), raggruppati per giorno di `updatedAt` (altrimenti `dueDate`, altrimenti `createdAt`), dal più recente.
- L'ordine dentro ogni gruppo è **quello del server**. Un lavoro visto solo nel dettaglio (es. da una notifica)
  va in fondo.
- La ricerca guarda titolo, `assetTag`, zona e categoria.
- Un lavoro è «scaduto» se è aperto e `dueDate < adesso`.
- `GET /v1/mobile/work-orders?status=open&limit=50` per gli aperti; `?status=closed&limit=200` per i passati
  (200 è il massimo). La lista si ricarica **all'apertura e al ritorno in primo piano** (non più di una volta al
  minuto), col pull-to-refresh (sempre) e quando arriva una notifica push.
- **404 sul dettaglio** = l'ordine non è più dell'operatore (riassegnato): sparisce dalla lista, senza errori.

### 5.3 Dettaglio di un lavoro

Risponde a «cosa faccio adesso?»:

- intestazione: stato, priorità, scadenza, titolo, asset e zona;
- **sicurezza** (`procedure.safetyWarnings`) in evidenza e aperta prima di iniziare; ripiegata a lavoro iniziato;
- la **checklist dei passi** con il prossimo passo evidenziato e l'avanzamento;
- risorse (`toolsNeeded`, `partsNeeded`), e una scheda con **Descrizione / Note / Dettagli** (chiuse di partenza,
  ognuna con un'anteprima di una riga; si aprono al tocco). Descrizione e note sono **testo libero** (sezione 5.6);
- un pulsante sempre in vista in fondo: **Start** (nessun passo fatto) → **Continue** → **Complete task** (tutti i
  passi hanno un risultato) → **Review steps** (lavoro chiuso).

### 5.4 Esecuzione dei passi

Schermata a tutto schermo, **un passo alla volta**, con pallini di avanzamento, schede Note e Foto e «Ask AriA».

- **Done / Not done** mettono il risultato (`PUT …/steps/{id}`). **«Not done» vuole sempre un motivo** (nota).
  «Done» ha la nota facoltativa. **«Undo»** toglie il risultato **e le sue foto**.
- Nota: massimo **2000 caratteri**. La nota di un passo ancora senza risultato è una **bozza** e parte con il
  risultato.
- Il **primo risultato porta l'ordine in `in_progress`** (lo fa il server; l'app lo riproduce in locale).
- **Un passo si indirizza sempre per `id`** (12 caratteri esadecimali minuscoli), **mai per `number`**: un planner
  può modificare l'elenco dal desktop.
- Cambiare l'esito lascia le foto già caricate (il `PUT` le conserva).
- Un lavoro **chiuso è in sola lettura**. All'apertura, se nessun passo ha un risultato e ci sono avvertenze, la scheda sicurezza si apre da sola.
- **Chiusura:** servono le **note di chiusura** (obbligatorie) e **tutti i passi con un risultato**; altrimenti
  `steps_incomplete` (con l'elenco `missing`) o `resolution_notes_required`.
- **«Ask AriA»** apre la chat con il contesto del passo (sezione 9.6). Cambiando passo la conversazione riparte da
  zero col contesto del nuovo passo, anche a foglio aperto.

### 5.5 Foto

- **Al massimo 3 per passo**, **10 MB**, solo **JPEG** (i desktop non mostrano HEIC). Il passo deve avere già un
  risultato (`step_not_reported` altrimenti).
- Compressione prima dell'invio: JPEG a qualità 0,85 → 0,6 → 0,4; se ancora oltre 10 MB si riduce a 0,7× in pixel e
  si riprova, fino a 4 volte.
- Sorgente: galleria o fotocamera (`AriaPhotoSourceSheet`).
- **Upload in 3 passi:**
  1. `POST …/steps/{id}/photos` `{"mimeType": "image/jpeg", "sizeBytes": N}` → `201 {photoId, upload: {url, fields}, expiresIn}`;
  2. `POST` multipart all'**URL di S3** dato dal server: ogni voce di `fields` come parte di testo, poi il file
     **per ultimo** con nome `file`. Il `Content-Type` e la dimensione devono essere quelli dichiarati, **senza
     header `Authorization`** (non è il nostro host). Risposta `204`. L'URL deve essere `https`; nomi e valori dei campi
     non possono contenere a capo o virgolette;
  3. `POST …/photos/{photoId}/confirm` → il passo con la foto (ripetere la conferma non fa danni).
- `DELETE …/photos/{photoId}` toglie una foto e restituisce il passo.
- **L'URL di una foto scade dopo 10 minuti**: non si conserva, si ricarica l'ordine.

### 5.6 Testo formattato (descrizione, note, passi)

Descrizione e note arrivano come testo libero scritto a mano o da un gestionale. L'app lo legge riga per riga e lo
divide in blocchi (`AriaFormattedText.parse`, con test in `FormattedTextTests`):

- **Titolo:** `## Titolo`, oppure una riga **tutta in maiuscolo** (3–60 caratteri, almeno 3 lettere, senza `:` interno e
  senza punto finale), oppure `Etichetta:` da sola sulla riga.
- **Elenco puntato:** righe che iniziano con `-`, `*`, `•`, `–`, `·`, `▪`, `‣`. **Elenco numerato:** `1.` o `1)` (fino a
  2 cifre). Una riga **rientrata** sotto una voce la continua.
- **Campi:** `Etichetta: valore` (etichetta di al massimo 4 parole). Due punti dentro un orario («10:30») non contano.
- **Paragrafi:** ogni riga resta una riga; una riga **più lunga di 280 caratteri** con almeno 3 frasi si divide a
  gruppi di frasi (obiettivo ~200 caratteri).
- Inline: `**grassetto**`, `_corsivo_`, `` `codice` ``; se il Markdown non si legge, il testo com'è.

Il **testo di un passo** (`AriaStepText`) si divide per leggerlo sul telefono: un'etichetta in testa in maiuscolo
(«SAFETY FIRST: …») diventa una pastiglia; la prima frase è l'azione e resta in evidenza; un elenco dopo i due punti
diventa puntato; le frasi successive sono le indicazioni. Le frasi si dividono con `NLTokenizer` (conosce le
abbreviazioni, «e.g.», «ecc.»): su Android usare `BreakIterator` o una libreria equivalente.

### 5.7 Calendario

Un mese con un puntino per ogni lavoro del giorno (**rosso** se in ritardo, **verde** se chiuso), e sotto le task del
giorno scelto con le stesse schede della lista. **Un lavoro sta nel giorno di `scheduledDate`; senza, in quello di
`dueDate`**; senza nessuna delle due non compare.

### 5.8 Impostazioni e disponibilità

- **Disponibilità:** `available`, `busy`, `off_duty`. **`available` dura 12 ore** lato server: l'app lo **rimanda
  all'apertura e a ogni ritorno in primo piano** (rimandare lo stesso valore riparte da 12 ore). `busy` e `off_duty`
  non scadono. Di partenza è `available`, altrimenti l'operatore non riceverebbe mai ordini. Scelta offline: parte
  appena torna la rete.
- Il cambio di disponibilità ricarica la lista (cambia cosa arriva).
- Altro: profilo (nome/email dell'operatore); «Aria server» (stato della connessione, «Online»/«Not connected», e accesso; i campi per cambiare host e incollare un token esistono **solo nelle build di debug**); **Logout**. Con modifiche non ancora arrivate al
  server il logout chiede conferma («N changes haven't reached the server yet. If you log out now, they will be lost.»).
- **Logout:** toglie il token push dal server (finché la sessione vale), chiude la sessione, azzera chat, progressi e
  dati dei lavori, rimuove le notifiche già ricevute.

---

## 6. API `/v1/mobile` e dintorni

Tutte sull'host dati, con gli header della sezione 3. Un ordine che non è dell'operatore risponde **404**.

| Metodo e percorso | Body | Risposta |
|---|---|---|
| `GET /v1/companies` | (nessun `Company-Id`) | `[{id, name, myRole}]` |
| `GET /v1/mobile/plants` | | `[{id, name, code, location}]` |
| `GET /v1/mobile/me` | | profilo `{id, name, email, specialties[], availability, availabilityAt}` |
| `PUT /v1/mobile/me/availability` | `{"availability": "available"\|"busy"\|"off_duty"}` (**nessun altro campo**: 422) | il profilo |
| `GET /v1/mobile/work-orders?status=open\|closed\|all&limit=N` | | array di ordini (si accetta anche un oggetto con `items`, `workOrders` o `data`) |
| `GET /v1/mobile/work-orders/{id}` | | ordine + `procedure` |
| `PUT /v1/mobile/work-orders/{id}/steps/{stepId}` | `{"status": "done"\|"not_done", "note"?: "…"}` (senza `note` il campo manca del tutto) | il passo. **Idempotente**: si può rimandare dopo una caduta di rete |
| `DELETE /v1/mobile/work-orders/{id}/steps/{stepId}` | | `204`; toglie risultato e foto |
| `POST …/steps/{stepId}/photos` | `{"mimeType", "sizeBytes"}` | `201 {photoId, upload:{url, fields}, expiresIn}` |
| `POST …/steps/{stepId}/photos/{photoId}/confirm` | | il passo con la foto |
| `DELETE …/steps/{stepId}/photos/{photoId}` | | il passo |
| `POST /v1/mobile/work-orders/{id}/complete` | `{"resolutionNotes": "…"}` | l'ordine chiuso (`completed`) |

### Modello dell'ordine

`id`, `title`, `description?`, `type` (`reactive`/`preventive`), `category?`, `priority` (`high`/`medium`/`low`),
`status` (`proposed`/`planned`/`assigned`/`in_progress`/`completed`/`verified`/`cancelled`), `assetTag?`, `plantId?`,
`zone?`, `scheduledDate?`, `dueDate?`, `estimatedDurationMin?`, `assignedAt?`, `assignmentSource` (`auto`/`manual`),
`notes?`, `createdAt?`, `updatedAt?`, `progress {done, notDone, total}`, e **solo nel dettaglio**
`procedure {steps[], safetyWarnings[], toolsNeeded[], partsNeeded[], progress}`.

- **Passo:** `{id, number, text, report?}`. **Risultato:** `{status: done|not_done, note?, photos[{id, url?, mimeType}], reportedAt?}`
  (`reportedAt` è assente se il passo l'ha spuntato un planner dal desktop).
- **`safetyWarnings`, `toolsNeeded`, `partsNeeded`** possono arrivare come **stringhe o come oggetti** (`name`, `text`,
  `description`, `title`): l'app prende il primo campo di testo non vuoto.
- **Robustezza:** i valori fissi (`status`, `priority`, `availability`…) si leggono come stringhe e si interpretano con
  proprietà tipizzate: **un valore nuovo del server non deve far fallire la lista intera**. Un campo sconosciuto →
  `null`, non un errore.
- **Date:** ISO-8601 UTC con `Z`, **con cifre decimali dei secondi variabili o assenti** (`…:00Z`, `…:00.1Z`,
  `…:00.120000Z`, `…:00.123456789Z`) e a volte con offset `+02:00`; a volte solo data (`2026-10-07`). L'app toglie la
  frazione e legge il resto. Su Android: non usare un pattern fisso.

### Errori

- **`detail.code`** noti (la risposta è `4xx` con `{"detail": {"code": "…", "message": …}}`; per `steps_incomplete` c'è
  anche `detail.missing`: gli id dei passi senza risultato): `step_not_found`, `photo_not_found`, `work_order_closed`,
  `step_not_reported`, `photo_limit_reached`, `photo_not_uploaded`, `steps_incomplete`, `note_required`,
  `note_too_long`, `unsupported_media_type`, `photo_too_large`, `resolution_notes_required`, `storage_unavailable`.
- Formati di errore da gestire: FastAPI `{"detail": "…" | [{"msg": …}] | {"code", "message"}}`, `aria-backend`
  `{"error": {"message", "code"}}`, better-auth `{"message", "code"}` o `{"error": "…"}`.
- **Controlli locali prima di chiamare** (stessi del server, evitano un giro a vuoto): nota obbligatoria per
  `not_done`, nota ≤ 2000, foto ≤ 10 MB, note di chiusura non vuote, tutti i passi con un risultato.

---

## 7. Sync offline local-first [in lavorazione, non committato]

L'iOS lavora **sempre sul database locale** e sincronizza dopo. Tutto quello che segue è nei file
`AriaOfflineStore`, `AriaWorkOrderOverlay`, `AriaWorkOrderStore(+Sync)`, `AriaNetworkMonitor`. Il comportamento è
coperto da `OfflineSyncTests` (28 test) e `WorkOrderOverlayTests` (15).

> Il codice è stato scritto il 19/10 ed è ancora in corso: le regole sotto sono quelle di oggi. *Non verificato su
> dispositivo.*

### Modello dei dati

- **Copia del server**, salvata come arriva (JSON) e riletta con i modelli di sempre: per ordine, la riga della
  lista (`bucket` `open`/`closed`, `position` = posizione nella lista del server) e, se scaricato, il dettaglio con
  la procedura; più il profilo (`me`).
- **Coda delle modifiche** (outbox), una riga per modifica, in ordine di arrivo: `report(stepId, status, note, at)`,
  `clearReport(stepId)`, `addPhoto(stepId, localId)` con il JPEG **fuori dalla riga**, `removePhoto(stepId, photoId)`,
  `complete(notes, at)`.
- **Ogni riga appartiene a un account:** un altro operatore sullo stesso telefono non vede niente, e una sessione
  scaduta non perde il lavoro ancora da mandare. All'accesso si tengono solo i dati dell'account entrato.
- Id locale delle foto non ancora partite: prefisso **`local-`** + UUID.

### Come si vede un ordine (overlay)

L'ordine mostrato = copia locale **+ coda applicata nell'ordine**, ricalcolata a ogni modifica: lista, dettaglio,
runner e calendario mostrano subito il lavoro fatto, anche offline, e **continuano a mostrarlo sopra i dati freschi**
finché la coda non è vuota. L'applicazione:

- `report`: imposta `report{status, note, photos (conservate), reportedAt}`; **il primo risultato porta
  `proposed/planned/assigned` in `in_progress`**.
- `clearReport`: `report = null`. `removePhoto`: toglie la foto dal passo.
- `complete`: `status = completed`, `updatedAt = at`, e se l'ordine non ha `notes` ci mette le note di chiusura.
- `addPhoto`: non si applica al JSON (non ha URL): la mostra chi esegue i passi, dalla coda.
- `progress` si **ricalcola dai passi** (`done`, `notDone`, `total`).

**Unione lista + dettaglio:** nei campi comuni vince quello con `updatedAt` più recente; a parità, quello scaricato
dopo. La procedura c'è solo nel dettaglio e **resta anche se il dettaglio è più vecchio**.

### Fusione della coda (meno chiamate, stesso risultato)

Quando entra una modifica nuova:

- **`report`** su un passo che ha già un `report` in coda (senza un `clear` in mezzo) → **sostituisce** quello (il PUT
  è idempotente).
- **`clearReport`** → scarta tutto quello in coda per quel passo (esito, foto da caricare, foto da togliere); si
  accoda il `DELETE` **solo se sul server c'è qualcosa da togliere** (il passo ha un risultato nell'ultimo JSON del
  server) o ce n'era già uno in coda.
- **`removePhoto` di una foto `local-…`** → basta toglierla dalla coda, **non parte niente**.
- **`complete`** già in coda → sostituisce le note.
- `addPhoto` e `removePhoto` di foto del server si aggiungono in fondo.

### Quando e come parte la coda

- **A lotti:** mentre si lavora le modifiche aspettano **60 s** dall'ultima (`batchDelay`): tocchi di fila partono
  insieme. Partono **subito** alla fine della procedura (chiusura dell'ordine, uscita dall'esecuzione), quando l'app
  va in background, al ritorno in primo piano e **al ritorno della rete**.
- **In ordine:** un passo prima delle sue foto, tutti i passi prima della chiusura.
- **Una sola rilettura per ordine** a fine lotto (servono gli URL delle foto e le modifiche di un planner). L'ordine
  chiuso in questo lotto non si rilegge: la risposta di `complete` è già l'ordine aggiornato.
- **Esiti di un errore** (`classify`):
  - rete assente / server giù / `5xx` / `429` / `photo_not_uploaded` / `storage_unavailable` → **si riprova più tardi**,
    con attesa crescente **30 s → 60 → … fino a 10 min**, e la coda si ferma lì (segnata l'ultima prova);
  - `401` → sessione finita (si torna al login; **la coda resta** per quando lo stesso operatore rientra);
  - **`404` sull'ordine** → non è più suo: si toglie con tutta la sua coda e si dice all'operatore;
  - qualunque **rifiuto del server** (`work_order_closed`, `step_not_found`, limite foto…) → la modifica si **scarta**
    e finisce nell'elenco «problemi di sincronizzazione» (`syncIssues`), mostrato finché l'operatore non l'ha visto.
- **`complete` in linea:** se c'è rete, parte subito tutto il lotto e gli errori del server (es. `steps_incomplete`)
  tornano **all'operatore come errore della chiusura**, non come problema di sync. Offline la chiusura aspetta in coda.
- **Prefetch dei dettagli:** dopo la lista si scaricano, **tre alla volta**, solo i dettagli degli ordini aperti
  cambiati sul server (`updatedAt` della lista > quello del dettaglio) o mai scaricati (senza date, se hanno più di
  un giorno), così la procedura c'è anche offline. **Con «Risparmio dati» attivo non si fa.**
- **Freschezza:** la lista non si riscarica se ha meno di 60 s (tranne col pull-to-refresh); un dettaglio con meno di
  30 s non si riscarica aprendolo.
- Una modifica richiede che **l'ordine sia già sul telefono**: altrimenti «This task isn't saved on the phone yet. Open
  it once while online.»

### Rete e interfaccia

- Monitor di rete: online/offline, rete a consumo, risparmio dati. **Offline non si prova nessuna chiamata** (niente
  timeout che scaricano la batteria). La rete «c'è» non vuol dire che il server risponda: la verità finale sono gli
  errori delle chiamate.
- Una **pillola di stato** dice: offline (e quante modifiche aspettano), invio in corso, modifiche in attesa (con «Invia
  ora»), modifiche rifiutate dal server. Quando è tutto a posto non si vede.

### Suggerimento di mappatura su Android *(non è nel codice iOS)*

Room per la copia e la coda, WorkManager per il lotto in background (vincolo di rete, backoff esponenziale 30 s → 10 min),
`ConnectivityManager.NetworkCallback` per il monitor, `ConnectivityManager.restrictBackgroundStatus` per il risparmio dati.
Le regole di fusione e di classificazione degli errori sono pure e sono il pezzo da portare **tale e quale**.

---

## 8. Notifiche push

**Stato: il backend non le ha ancora.** Il contratto sotto è una **proposta** scritta nel client iOS (follow-up delle spec
del 7/10). Il 19/10 ho cercato `push-tokens`, `apns`, `fcm`, `firebase` in `aria-backend` (`main`, `dev`,
`feature/mobile-chat`): **nessuna route e nessun invio**. Finché non esistono, l'app ignora in silenzio `404`/`405`.

```
PUT    /v1/mobile/me/push-tokens/{token}   {platform, environment, bundleId, locale, appVersion}  → 204
DELETE /v1/mobile/me/push-tokens/{token}                                                          → 204
```

- `token` è il device token APNs in esadecimale. Il `PUT` è un **upsert sul token**: se lo stesso telefono entra con un altro
  account, il token passa al nuovo operatore. `environment` è `sandbox` o `production`.
- **Android:** FCM; `platform: "android"` e `environment` da concordare col backend. *Non definito*: serve una decisione
  del backend prima di implementarlo.
- Payload atteso dall'app:

  ```json
  { "aps": { "alert": { "title-loc-key": "WORK_ORDER_ASSIGNED_TITLE", "body": "<titolo dell'ordine>" },
             "sound": "default", "badge": 1, "thread-id": "work-orders" },
    "type": "work_order_assigned", "workOrderId": "<id dell'ordine>" }
  ```

  `title-loc-key` si traduce **sul telefono**, così il server non deve conoscere la lingua. Su Android usare un messaggio
  `data` con gli stessi campi (`type`, `workOrderId`) e `title`/`body` localizzabili.
- Un `type` sconosciuto non impedisce di aprire l'ordine (basta `workOrderId`).
- **Tocco** → si va ai Task e si apre il lavoro. **Notifica con l'app aperta** → banner e la lista si ricarica.
- Il permesso si chiede **dopo l'accesso**; senza permesso non si registra; se lo si dà più tardi dalle impostazioni, al
  ritorno in primo piano si riprova. Il token si ri-registra a ogni apertura e a ogni ritorno (può cambiare).
- **Al logout** il token si toglie dal server **prima** che la sessione si chiuda (attesa massima 4 s), si rimuovono le
  notifiche già consegnate (portano i titoli dei lavori) e il badge si azzera.

---

## 9. Chat con Aria

### 9.1 Cosa può fare un operatore (e cosa no)

Un operatore riceve `403 mobile_user_forbidden` su ogni rotta **fuori da `/v1/mobile/`**. Ha:

| Azione | Rotta |
|---|---|
| Invio di un messaggio, in streaming | `POST /v1/mobile/responses` (stesso body e stesso stream di `/v1/responses`) |
| Storico delle sessioni | `GET /v1/mobile/chat/sessions?limit=60&offset=N` |
| Messaggi di una sessione | `GET /v1/mobile/chat/sessions/{id}/messages` |
| Pausa in attesa | `GET /v1/mobile/chat/sessions/{id}/pending-interrupt` |

**Non hanno rotta per l'operatore** e l'app **non le chiama** (errore `notOnPhone` o niente): rinomina ed eliminazione
sessioni, suggerimenti iniziali, feedback sulle risposte e sui task, review, apprendimento (learning), memoria
(validazione e conferma dei fatti), chiusura intervento (closeout), trascrizione audio sul backend (la dettatura usa
il riconoscimento del telefono). Se il backend le aggiunge basta togliere le guardie `isOperator` in `AriaChatAPI.swift`.

### 9.2 Richiesta

`POST /v1/mobile/responses`, header `Accept: text/event-stream`, body JSON (snake_case, **≤ 8000 byte**):

```json
{ "input": "…", "plant_id": "…", "session_id": "<nanoid 21>", "company_id": "…",
  "stream": true, "stream_options": {"include_usage": true},
  "include_metadata_events": true, "include_trace": false,
  "model": "default", "style": "auto|detailed|compact", "locale": "it|en",
  "instructions": "…", "tool_call": {"tool_name", "args"}, "resume": {…} }
```

- `input` è **solo il testo nuovo**: la storia la tiene il backend, legata a `session_id`.
- `plant_id` obbligatorio (422 senza). `include_metadata_events: true` serve, **senza** non arrivano tool call, artefatti
  né interruzioni. `include_trace` è solo per l'admin della web.
- `session_id` è un **nanoid di 21 caratteri** generato dal client, alfabeto `useandom-26T198340PX75pxJACKVERYMINDBUSHWOLF_GQZbfghjklqvwyzrict`.
- `instructions` = testo identico a `buildInstructions` della web (scopo + «Web search is enabled/disabled» + «Task progress
  context (from user checkboxes): …» quando c'è un riepilogo delle spunte). Una chiamata diretta a un tool **non** porta
  modello, stile né istruzioni.
- Riepilogo dei task per il contesto: `Step 2 "Titolo": completed [1,3], pending [2].`
- Il `locale` fissa la lingua della sessione al primo turno.
- Un `401` si ritenta una volta come per le altre chiamate.

### 9.3 Eventi dello stream (SSE)

Frame separati da una riga vuota; righe `event:` e `data:` (più righe `data:` si uniscono con `\n`); righe che iniziano con `:`
sono commenti/keep-alive; **un frame oltre 1 MB si scarta fino alla riga vuota** (un server che non la manda mai non fa
crescere la memoria).

| `event` | Effetto sul messaggio |
|---|---|
| `response.created` | memorizza `responseId` |
| `response.output_text.delta` | **accumula** il testo |
| `response.output_text.done` | la copia finale pulita **sostituisce** il testo accumulato (se non è vuota) |
| `response.reasoning_summary_text.delta` | accumula il ragionamento |
| `response.completed` | fine; `status: "failed"` → errore «The response failed.»; porta `usage` |
| `error` | errore con `message` |
| `aria.tool_call` | aggiunge o aggiorna per `id` (stato `running`/`ok`/`error`/`proposed`/`rejected`, rischio `safe`/`review`/`destructive`) |
| `aria.ui_artifact`, `aria.ui_action`, `aria.image_reference` | aggiunge, senza doppioni |
| `aria.elicitation` | domanda guidata (si usa solo se ha **almeno 2 opzioni**) |
| `aria.sources` | fonti, senza doppioni per URL/titolo |
| `aria.memory_context_loaded`, `aria.memory_learned`, `aria.memory_proposal` | memoria |
| `aria.answer_confidence`, `aria.validation_request` | verdetto di confidenza e domanda di validazione (si **uniscono**: il server manda il verdetto più volte) |
| `aria.diagnostic_state` | numero dell'episodio |
| `aria.interrupt` | pausa di approvazione o di LOTO (sezione 9.4) |
| `aria.task_list` | checklist di uno step (sezione 9.5) |
| altri | si conservano come «pipeline» o si ignorano; **un evento sconosciuto non deve rompere lo stream** |

I campi che il server può omettere o cambiare (`allow_custom`, `mode`, `steps`, array con elementi malformati) si
leggono in modo **tollerante**: un elemento rotto non fa perdere gli altri.

**Ritmo del testo (`StreamPlayback`):** il testo esce a **tick di 50 ms** (ridisegnare a ogni token faceva restare
indietro il testo anche di mezzo secondo). Un pezzo **più lungo di 120 caratteri** arrivato in un colpo solo esce **a
fette** (~20 caratteri a tick, al massimo 40 fette, tagliate a fine parola). È il **gate di sicurezza**: il backend
non manda il verdetto token per token (la parola «SAFE» non deve arrivare all'operatore) ma **tutto insieme**, a
modello finito; lo stesso per le tabelle di chiusura. Il blocco ```` ```elicit ```` in fondo al testo **non si vede**
(diventa il pannello di domande) ed esce in una volta. Ogni altro evento esce dopo il testo arrivato prima di lui.

**Errori:** se lo stream cade, quello che è già arrivato si mostra subito, tutto; rete assente → messaggio «offline»
con «Retry»; **errore durante una ripresa → la pausa torna**, così si può riprovare.

### 9.4 Pause: approvazione e LOTO

`aria.interrupt` → `{interrupt_id, kind: "tool_approval"|"loto", id, name, args, risk, alarm_code, warning}`.
Si risponde con un nuovo `POST` **con `input: ""`** e `resume`:

| Scelta | `resume` |
|---|---|
| Approva | `{"interrupt_id", "decision": "approve"}` |
| Approva modificando | `{"interrupt_id", "decision": "edit", "args": {…tutti gli args…}}` |
| Rifiuta | `{"interrupt_id", "decision": "reject"}` |
| LOTO | `{"interrupt_id", "confirmed": true\|false}` |

La continuazione arriva **nello stesso messaggio** (si aggiunge `\n\n` al testo prima di riprendere). Riaprendo una chat,
`pending-interrupt` riporta la pausa ancora in attesa. Mentre c'è una pausa **non si può mandare un nuovo turno**.

### 9.5 Domande guidate e procedura a checklist

- **Domanda guidata** (`aria.elicitation`): `{id, question, mode ("single"/…), allow_custom, options[{id, label, description,
  follow_up, value}], steps[], assembly{intro}, topic, submit, reason}`. Una domanda singola è una catena di un passo.
  `submit: "review"` è la valutazione di fine sessione; `reason: "closure_confirmation"` è la conferma di fine procedura
  (chi sceglie «end» deve dire anche perché). Le risposte tornano come **un nuovo turno di testo**; le risposte di tipo
  `learning` hanno una chiamata a parte (non disponibile per l'operatore).
- **Checklist** (`aria.task_list`): `{agent ("safety"|…), step_number, step_title, step_label, revision, tasks[{id, index, text}]}`.
  Compare in basso al posto della domanda, **un task alla volta**: «Done» spunta, «Back» torna indietro, e un menu chiede aiuto
  su quel task. Finita la checklist compare la domanda.
- **Messaggi di aiuto sul task: testo inglese esatto, lo riconosce il backend, NON tradurre:**
  - `"<label>, task <n> (\"<testo>\"): I don't understand this step. Explain it in more detail before we continue."`
  - `"…: I need to change how this is done. Propose an adjusted version of this step."`
  - `"…: this step FAILED. Do not move on to the next step — help me work out what went wrong and give me a corrected version of this step."`
  - libero: `"<label>, task <n> (\"<testo>\"): <testo dell'operatore>"`
  - `label` = `step_label` del backend, altrimenti «Step N» / «Safety N». Fine procedura: `"End the procedure"`.
- **Le spunte non dipendono dall'id del messaggio** (in streaming è un UUID, ricaricato dal server diventa `db-…`): la chiave è
  `<agent>:<step_number>:r<revision>:<task id>`; ogni revisione di uno step ha le sue spunte.
- **Persistenza locale (`AriaTaskProgress`, `AriaSavedTaskList`):** le spunte e le segnalazioni (`unclear`/`modify`/`failed`) per
  conversazione, **e le checklist stesse**, perché **il backend le manda solo in streaming e non le mette nello storico**: senza
  questa copia, riaprendo la chat gli step sparirebbero. Le checklist si legano alla risposta tramite `responseId`, ordinate per
  indice di risposta dell'assistente.
- **Duplicati:** il modello spesso riscrive nel testo quello che arriva anche come pannello (opzioni «A. … B. …» e task della
  checklist). `AriaPanelDedup` toglie dal testo quegli elenchi e la riga che li introduce.

### 9.6 La chat dentro un passo («Ask AriA»)

- Si crea una **chat nuova per ogni passo** col contesto del passo; la vecchia smette di rispondere. Il contesto viaggia **solo con
  il primo messaggio**: `"[Work order context]\n<contesto>\n---\n<testo>"`.
- Contesto (`chatContext`), righe: `Work order: <titolo>`; `Asset: … | Zone: … | Priority: … | Category: … | Type: …`;
  `Description: <≤1200 caratteri>`; `Procedure step N of M: <≤600>`; `Step result so far: done|not done (note: <≤400>)`;
  `Safety warnings: <unite con "; ", ≤600>`. **I testi lunghi si tagliano con «…»** per restare sotto gli 8000 byte.
- Chiudere il foglio **minimizza** soltanto: la conversazione resta e si riapre da «Ask AriA».

### 9.7 Sessioni, storico e ripristino

- **Chat principale:** ricorda l'ultima conversazione (`aria.chat.current_session`) e la riapre all'avvio; una sessione che
  il server non conosce più (404) si dimentica senza errore. «New chat» genera un nuovo `session_id` e azzera messaggi, spunte,
  contesto e card di apprendimento.
- **Storico:** pagine da 60; le sessioni `__briefing-*` sono interne e si **nascondono**; si possono fissare (preferenza
  locale, `aria.chat.pinned_sessions`), cercare per titolo, raggruppare per data e aprire. **Rinomina ed elimina esistono
  nell'interfaccia ma per un operatore non hanno rotta** (`notOnPhone`): su Android conviene nasconderle.
- **Riaprire una sessione:** `messages` + `pending-interrupt`. Le domande guidate già superate da un turno successivo non
  vanno riproposte. I messaggi salvati si riconoscono dall'id con prefisso `db-`.
- **Stile di risposta** (`auto`/`detailed`/`compact`) ricordato sul telefono (`aria.chat.style`).
- **Rigenera:** rimanda la domanda precedente come nuovo turno.

### 9.8 Rendering del Markdown delle risposte

Blocchi: titoli, paragrafi, elenchi (anche annidati), citazioni, codice, **tabelle**, linea orizzontale. Inline: grassetto,
corsivo, codice, link. Le tabelle piccole (fino a due colonne) restano tabelle; le più larghe diventano schede una per riga.
**Costo:** il parsing di un testo di 3,6k caratteri costa ~5,6 ms (`blocks`) e ~2,9 ms per ogni paragrafo (`inline`); l'iOS ora
**ricorda i risultati** per testo. Su Android: tenere in memoria il parse per stringa, o fare il parse una volta quando il testo
cambia, **non a ogni ricomposizione**.

### 9.9 Dettatura e voce

- **Dettatura:** riconoscimento sul telefono (SFSpeechRecognizer) con la lingua scelta nel menu «···» (automatica o una di 22),
  massimo **2 minuti**, niente invio sotto i 350 ms. Per un operatore **non c'è** la trascrizione Whisper
  (`/v1/audio/transcriptions` non è sotto `/v1/mobile`): resta il testo del telefono.
- **Voce (modalità vocale):** token effimero `GET {voice host}/token` con header `x-aria-password` (chiave da configurazione) →
  `{value, expires_at}`; WebSocket a `wss://api.openai.com/v1/realtime?model=gpt-realtime-1.5` con quel token;
  `session.update` con audio bidirezionale, VAD, voce `alloy`, trascrizione `gpt-4o-transcribe`; funzione `search_knowledge_base`
  → `POST {voice host}/rag/search {query, topK}`. **Richiede iOS 27** (API audio nuove): sulle versioni precedenti l'app mostra
  «Voice requires iOS 27 or later. Use text chat instead.» Su Android è tutto da riprogettare con le API del sistema.
- **Annotazione nota del progetto:** `/token` del motore vocale emette chiavi OpenAI **senza un'autenticazione vera** (la chiave
  in `Info.plist` viaggia dentro il binario e non è un segreto). *Segnalato in precedenza; non riverificato oggi.*

### 9.10 Avviso dall'isola (iOS-only)

Il Real-time Learning annuncia la sua domanda con una capsula dalla Dynamic Island («Answer»/«Not now»). Non ha un equivalente
diretto su Android: *suggerimento:* heads-up notification o snackbar con azioni.

---

## 10. Cose iOS da non portare tali e quali

| iOS | Android *(suggerimento)* |
|---|---|
| Keychain con `.userPresence`, Face ID | Keystore + `BiometricPrompt` |
| `ASWebAuthentication` / link universali (`applinks:`) | App Links (`assetlinks.json`, `autoVerify`) |
| SwiftData (`@Model`) | Room |
| `NWPathMonitor` | `ConnectivityManager.NetworkCallback` |
| `UIApplication.beginBackgroundTask` per il lotto | WorkManager con vincolo di rete |
| APNs | FCM |
| Liquid Glass / `glassEffect` (iOS 26), sfera animata con shader Metal | Material 3 / Compose; la sfera (`AriaOrb.metal`) è una scelta di marca da decidere |
| Dynamic Island | notifica o snackbar |
| `NLTokenizer` | `BreakIterator` |
| Voce Realtime iOS 27 | riprogettare |

---

## 11. Localizzazione

- **Italiano e inglese**, inglese come lingua sorgente; segue la lingua del sistema (nessun selettore in app).
- Stringhe in `Localizable.xcstrings` (circa 500 attive). Su Android: `strings.xml` in `values/` e `values-it/`.
- **Non localizzare** le stringhe che il backend riconosce: i messaggi di aiuto sul task, `"End the procedure"`, il prefisso
  `[Work order context]`, il testo di `buildInstructions`.
- Messaggi di errore di dominio (`detail.code`) si traducono sul telefono, mai si mostra il testo del server per i codici noti.
- Le notifiche usano `title-loc-key` risolto sul telefono.

---

## 12. Test come specifica

I test sono scritti con Swift Testing e sono la specifica eseguibile più affidabile: **310 test in 28 suite, tutti verdi il
19/10/2026** (di cui circa 24 «live» che si saltano senza variabili d'ambiente). Da portare come test di parità su Android:

| Area | File | Cosa fissano |
|---|---|---|
| Rete e header | `APIClientTests`, `HTTPErrorTests`, `StubNetwork` | retry su 401, header, WAF, mapping degli errori |
| Login e sessione | `AuthFlowTests`, `SignInLinkTests`, `BackendStateTests`, `ConnectionTests` | flusso a link, controlli sul dispositivo, rinnovo e fine sessione, bootstrap azienda/stabilimento |
| Modelli | `ModelsTests`, `ConfigTests`, `URLPolicyTests` | decodifica tollerante, date, host, SSE |
| Passi, foto, chiusura | `StepAPITests` | contratto di tutte le rotte `/v1/mobile` dei passi |
| Lista e store | `StoreTests`, `ResponsivenessTests` | sincronizzazione, offline, disponibilità, tempi |
| Offline | `OfflineSyncTests`, `WorkOrderOverlayTests` | fusione e invio della coda, regole di classificazione, overlay |
| Testo | `FormattedTextTests`, `StepTextTests`, `MarkdownTests` | regole di parsing delle sezioni 5.6 e 9.8 |
| Chat | `ChatTaskProgressTests`, `ClosureDialogTests`, `TaskProgressStoreTests` | persistenza di spunte e checklist, dialogo di chiusura |
| Push | `PushPayloadTests` | lettura del payload |
| Live | `LiveBackendTests` | **contro il server vero**, solo con `ARIA_LIVE=1` / `ARIA_LIVE_SESSION` e simili; non girano di default |

---

## 13. Aperti, rischi e cose non verificate

**Dipendenze dal backend / infrastruttura**

1. **Push:** nessuna route lato backend (sezione 8). Serve decidere il contratto per Android.
2. **App Links Android:** `assetlinks.json` risponde 404; servono `MOBILE_ANDROID_PACKAGE` e `MOBILE_ANDROID_CERT_SHA256` sul
   deploy di `aria-web` (stesso discorso per iOS con `MOBILE_IOS_APP_IDS`).
3. **Chat dell'operatore:** mancano le rotte mobile per rinomina/elimina, suggerimenti, feedback, review, learning, memoria,
   closeout e trascrizione (sezione 9.1).
4. **Rami del backend:** il router mobile della chat (`/v1/mobile/chat/*`, `/v1/mobile/responses`) è in `dev` (17/10) e in
   `feature/mobile-chat`, ma **non in `main`** (9/10, verificato il 19/10 con un clone shallow). Verificare quale ramo è in
   produzione prima di puntare Android a un host.

**Non verificato**

- Il comportamento **su dispositivo reale** (tutti i controlli sono stati fatti su simulatore e su test).
- La sync offline è **ancora in lavorazione e non committata**: le regole della sezione 7 possono cambiare.
- Il problema segnalato sul **layout del dettaglio con le note aperte** e sulla **lentezza dell'apertura della chat nel
  work order** non ha una causa accertata (misurato: il costo del Markdown, poi corretto con la cache; il resto non riprodotto).
  Se su Android si rifanno quelle schermate, cominciare con liste pigre, parsing fuori dal ciclo di composizione, e testare
  la scheda delle note con testi molto lunghi.
- Il comportamento esatto del server in alcuni casi limite (es. quante volte rimandare `PUT` dopo una caduta di rete)
  si deduce dai commenti del client, non da una specifica del backend.

**Cose pulite che l'Android non deve ricostruire** (rimosse il 19/10, esistevano solo come demo): vista Overview con widget,
Maintenance mode, ReportView, lista Demo dei work order, `MockData`, motore di chat finto, modello linguistico locale.
