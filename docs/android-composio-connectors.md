<!-- Created by Giovanni Michele on 30/10/26. -->

# Connettori Composio: handover per Android

Come l'app iOS (AriaLite) collega i connettori one-click di Composio (Gmail, Slack, Teams…) e cosa serve per
fare lo stesso su Android. È un'aggiunta all'handover generale [android-handover.md](android-handover.md).

- **Riferimento:** branch `admin-access`, commit `ac7a330` («fixed composio») più l'albero di lavoro del
  30/10/2026, non ancora committato.
- **Fonte:** il codice in `AriaLite/AriaLite/Admin/Marketplace/` e `Admin/Backend/AdminMarketplaceAPI.swift`, i test in
  `AriaLite/AriaLiteTests/Backend/ConnectorConsentTests.swift` e `AriaLiteTests/Chat/ConnectorConnectCardTests.swift`.
  `assetlinks.json` e l'AASA del sito li ho ricontrollati con `curl` il 30/10/2026.
- **Come leggere lo stato:** **[committato]** è in `ac7a330`; **[in lavorazione]** è solo nell'albero di lavoro.
  Quello che non viene dal codice iOS ma è un suggerimento per Android è marcato *(non è nel codice iOS)*.

---

## 1. Il problema in due righe

Dopo il consenso, Composio non rimanda al backend ma alla **pagina web**
`https://app.ariaplt.com/connectors/composio/verify?session_uri=…`. Quella pagina chiude il collegamento solo con
la **sessione web** dell'utente, che il telefono non ha. Quindi:

> **L'app deve intercettare quell'URL, leggere `session_uri` e chiamare lei
> `POST …/connectors/composio/complete`.** Se la pagina si apre in un browser qualsiasi, il collegamento non si chiude
> (a meno che in quel browser l'utente abbia già fatto l'accesso ad Aria sul web).

Il backend fissa questo redirect: l'app non può passare un `redirect_uri` suo (`me/oauth/start` non legge il body).
Una WebView non è un'alternativa, perché Google blocca il login OAuth nelle WebView incorporate.

Gli **altri** connettori OAuth (Notion, Odoo, OAuth aziendale) invece finiscono sul backend, che chiude da solo il
collegamento. Per quelli basta aprire il browser e ricaricare quando l'utente torna nell'app.

---

## 2. Rotte

Tutte sotto `/v1/companies/{company_id}/connectors`, con body e risposte in **snake_case** e gli header soliti
dell'API dati (vedi §3 dell'handover generale). `inspect` e `composio/complete` stanno **direttamente sotto
`/connectors`**, senza `{provider}`.

| Metodo | Percorso | Body | Risposta (campi usati) |
|---|---|---|---|
| GET | `/connectors` | — | `connectors[]`: `provider`, `mcp_url`, `connection_scope` (`user` = per membro), `status`, `last_error`, `my_grant` |
| POST | `/connectors/oauth/inspect` | `mcp_url` | `platform_client_available` (bool, può mancare) |
| PUT | `/connectors/{provider}/register` | `mcp_url`, `connection_scope: "user"`, `display_name` | la riga del connettore |
| POST | `/connectors/{provider}/me/oauth/start` | nessuno (il server non lo legge) | `authorize_url`, `expires_in?`, `scopes?` |
| POST | `/connectors/{provider}/oauth/start` | `request_write` (bool) | come sopra (consenso **aziendale**, mai Composio) |
| POST | `/connectors/composio/complete` | `session_uri` | `provider?`, `display_name?`, `account_email?` |
| DELETE | `/connectors/{provider}/me` | — | 204: scollega solo il mio account |
| DELETE | `/connectors/{provider}` | — | 204: toglie il connettore e le connessioni di tutti |
| GET | `/connectors/{provider}/grants` | — | `grants[]`: `user_id`, `account_email`, `status`, `connected_at`, `last_error` |
| DELETE | `/connectors/{provider}/grants/{user_id}` | — | 204: revoca la connessione di un membro |

Non c'è una GET del singolo connettore: per rileggerne uno si rilegge l'elenco e si prende la riga per `provider`.
Tutte le risposte vanno lette in modo tollerante: un campo mancante o di tipo inatteso non deve rompere la riga.

### Chi può fare cosa

- Le rotte dei connettori le chiama solo chi ha accesso pieno: `GET /v1/me` (con `Company-Id`) →
  `membership.restricted == false`. **Se `membership` manca, l'app non gestisce i connettori.** Una sessione
  operatore non le chiama mai (risponderebbero 403). **[in lavorazione]**
- Abilitare un one-click (`register`) e la domanda `inspect` sono azioni da owner/admin. Poi ogni membro collega il
  **proprio** account con `me/oauth/start`.

---

## 3. Riconoscere un connettore Composio

Un connettore è Composio se vale almeno una delle due:

1. `provider` è una delle dieci card one-click (da `toolkits.py` del backend) **[in lavorazione]**:
   `gmail-personal`, `calendar-personal`, `drive-personal`, `teams`, `outlook`, `dynamics-crm`, `salesforce-crm`,
   `slack-chat`, `asana`, `hubspot-crm`;
2. `mcp_url` (sulla riga del server, oppure `endpoint` nel catalogo locale) è **https** e l'host è `composio.dev` o un
   suo sottodominio (`*.composio.dev`). Un `http://…composio.dev` **non** è Composio.

Il punto 1 serve perché una riga può arrivare senza `mcp_url`. Il flusso Composio (intercettare il ritorno) parte
solo per il consenso **personale**: un consenso aziendale (`oauth/start`) va sempre nel browser.

---

## 4. I due flussi

### 4.1 Abilitare dal Marketplace (nessuna riga sul server)

Codice iOS: `AdminMarketplaceItemDetailViewModel.enable` e `prepare`.

1. **Prima di mostrare il pulsante** (solo se one-click + Composio + accesso pieno + nessuna riga sul server):
   `POST /connectors/oauth/inspect` con l'`endpoint` del catalogo, **una volta per pagina**.
   - `platform_client_available == false` → il server non ha il progetto Composio: «non disponibile», niente pulsante.
   - `true`, oppure il campo manca, oppure la chiamata fallisce → si lascia abilitare (in quel caso decide il server).
2. Al tocco: se la lista dei connettori non è ancora caricata, la si carica. Senza lista non si sa se la riga c'è già.
3. Se la riga **non** c'è, `PUT {provider}/register` con `mcp_url = endpoint`, `connection_scope = "user"`,
   `display_name = nome della card`. **Mai** su una riga che esiste già.
4. `POST {provider}/me/oauth/start` → `authorize_url`.
5. Consenso Composio (§5).
6. Si ricarica la lista. Se il consenso fallisce o viene annullato, la riga resta e la pagina offre «Apri connettore».

### 4.2 Collegare un connettore che esiste già

Codice iOS: `AdminConnectorDetailViewModel.consent`.

- **Personale** (`connection_scope == "user"`): `me/oauth/start`, poi §5 se è Composio, altrimenti browser.
- **Aziendale**: `oauth/start` con `request_write`, poi sempre browser.
- Esito: `connected` → avviso + ricarica; `cancelled` → ricarica una volta in silenzio (la web può aver chiuso da
  sola); `browser` → avviso + ricarica al rientro; `failed` → errore + rilettura della riga (il connettore può essere
  stato tolto nel frattempo).

---

## 5. Il consenso Composio, passo per passo

Codice iOS: `AdminConnectorConsentFlow.run` / `complete` e `AdminConnectorWebAuthentication.swift`.

1. **Controlla `authorize_url`**: deve essere `https` e avere un host. Se no → errore e si ferma. (Un controllo
   `startsWith("http")` lascerebbe passare `http` in chiaro e schemi come `httpx:`.)
2. **Memorizza il `company_id` usato per lo start.** Il `complete` va fatto con **quello**, non con l'azienda
   attiva in quel momento: Composio rifiuta la chiusura sotto un'altra azienda. **[in lavorazione]**
3. **Apri il consenso in una sessione del browser che condivide i cookie** (su iOS `ASWebAuthenticationSession`
   con `preferredBrowserSession: .shared`, così l'utente ritrova il login già fatto su Google/Microsoft) e aspetta il
   ritorno su `https://{web host}/connectors/composio/verify`.
4. **Sul ritorno** leggi il parametro di query `session_uri`. Se manca o è vuoto → «Impossibile completare l'accesso.
   Ricomincia.»
5. `POST /connectors/composio/complete` con `{ "session_uri": … }`.
   - OK → avviso «Collegato come {account_email}», oppure «{display_name} collegato» (se manca anche quello, il nome
     della card). Poi ricarica.
6. **Se la sessione del browser non parte o il ritorno non viene intercettato** (e non è stato l'utente ad annullare)
   → **ripiego**: apri `authorize_url` nel browser esterno, mostra «Completa l'accesso nel browser, poi torna qui.
   Funziona solo se in quel browser hai già fatto l'accesso ad Aria sul web.», segna `awaitingConsent = true` e al
   prossimo ritorno in primo piano ricarica **una volta** (su Android: `onResume`, su iOS: `scenePhase == .active`).
7. **Annullato dall'utente** → nessun errore, una ricarica silenziosa.

**Regole di sicurezza:**

- `session_uri` è monouso e appartiene a chi ha iniziato il consenso. **Non va loggato né salvato** da nessuna
  parte, nemmeno nei log di debug (su iOS il trace registra solo l'host dell'URL).
- Prima di usare un URL di ritorno, controlla che host e path siano esattamente quelli attesi.

---

## 6. Su Android: come intercettare il ritorno https *(non è nel codice iOS)*

### Dipendenza bloccante: `assetlinks.json`

iOS funziona perché il sito pubblica l'AASA con `webcredentials` per l'app iOS (è quello che autorizza il ritorno
https in `ASWebAuthenticationSession`). Per Android serve il corrispettivo:

```
curl -sI https://app.ariaplt.com/.well-known/assetlinks.json   →  404 (30/10/2026)
```

**Va pubblicato dal team web/backend** prima che il ritorno https funzioni su Android, con il package name e le
impronte SHA-256 del certificato di firma (debug, upload e Play App Signing):

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": { "namespace": "android_app", "package_name": "<package>",
              "sha256_cert_fingerprints": ["<SHA-256 debug>", "<SHA-256 release / Play>"] }
}]
```

Finché non c'è, l'unica strada è il ripiego del §5 punto 6 (browser esterno), che chiude solo se l'utente è
loggato sulla web in quel browser.

### Opzioni (da verificare sulle versioni che userete)

1. **Auth Tab** (`androidx.browser`, `AuthTabIntent`), che è il corrispettivo più vicino di
   `ASWebAuthenticationSession`. Accetta un redirect https con host e path (`app.ariaplt.com`,
   `/connectors/composio/verify`) e restituisce l'URL finale in un `ActivityResult`. Il redirect https richiede un
   Chrome recente e l'app verificata con Digital Asset Links per quell'host. Se Auth Tab non è supportato dal
   browser, si apre come Custom Tab normale: in quel caso vale l'opzione 2 oppure il ripiego.
2. **Custom Tab + App Link**: un intent filter `autoVerify="true"` su `https://app.ariaplt.com` con
   `pathPrefix="/connectors/composio/verify"`, gestito da un'activity che legge `session_uri` e chiama `complete`.
   Il Custom Tab condivide i cookie di Chrome come `.shared` su iOS. Attenzione: un redirect fatto dal server dentro
   un Custom Tab non sempre passa all'app, quindi va provato su più dispositivi.

In tutti e due i casi il viewmodel tiene `company_id`, il nome di ripiego e lo stato `awaitingConsent`
anche se l'activity viene ricreata (`SavedStateHandle`).

### Debug della verifica (l'analogo della saga iOS, §9)

- `adb shell pm get-app-links <package>`: lo stato deve essere `verified` per `app.ariaplt.com`.
- `adb shell pm verify-app-links --re-verify <package>` dopo ogni installazione, se la verifica è rimasta indietro.
- Una build debug firmata con la chiave di debug funziona solo se la sua SHA-256 è in `assetlinks.json`.

---

## 7. Errori

Codice iOS: `AdminMarketplaceFailure`. Il `message`/`detail` del server è scritto per la persona: quando c'è, si
mostra così com'è.

| Risposta | Significato | Cosa fa l'app |
|---|---|---|
| 401 / sessione scaduta | — | flusso di logout standard |
| 403 (`operation_forbidden`) | l'accesso è cambiato | messaggio di ruolo + rilettura di `/v1/companies` e `/v1/me` **[in lavorazione]** |
| 404 | connettore sparito | «Questo connettore non esiste più…» + rilettura della lista |
| 409 | `not_your_consent`, `not_confirmed`, `connector_removed`, OAuth al posto della chiave | mostra `detail`, rilegge la riga/lista |
| 410 (`consent_expired`) | link di consenso già usato o scaduto | `detail`, oppure «Questo link di accesso è già stato usato. Ricomincia.» |
| 502 (`gateway_rejected`) | Composio ha rifiutato | `detail` se è testo (non HTML), altrimenti come 503 |
| 503 / host irraggiungibile | Composio non raggiungibile | «Il servizio di collegamento non è raggiungibile. Riprova più tardi.» |

Su iOS il 403 su queste rotte non fa uscire dalla sezione: mostra il messaggio e resta sulla pagina.

---

## 8. La card «collega connettore» in chat **[in lavorazione]**

Aria può mandare in chat un artifact `connector-connect` (`aria.ui_artifact`). Su iOS è `AriaConnectorConnectCard`,
con il parsing in `AriaArtifactContent.connectorConnect`.

- Dati: `provider`, `label`, `scope`, `flow` (`composio`…), `state`, `callerCan`, `guide.sources[] { label, url }`.
- Titolo: `label`, poi `provider`. Se mancano tutti e due, la card non si mostra.
- `state` → testo: `not_connected` «Non collegato», `reconnect` «Da ricollegare», `needs_admin` «Deve collegarlo un
  owner o un admin», `not_available` «Non disponibile su questo server». Un valore sconosciuto non mostra nessuna riga.
- Link della guida: **solo `https` con un host**. `http`, `javascript:` e simili si scartano.
- Pulsante «Collega dal web» (apre `/marketplace` sulla web) tranne quando `callerCan == "none"` oppure
  `state == "not_available"`.
- **La card non raccoglie mai chiavi o codici** e non avvia il consenso dalla chat.

---

## 9. Cose iOS da non portare

Ci hanno fatto perdere tempo, ma su Android non esistono. Le scrivo perché sono il motivo dei commenti nel codice.

- **`canceledLogin` ambiguo:** iOS restituisce lo stesso errore sia quando l'utente chiude la finestra, sia quando
  l'app non risulta associata al dominio (`webcredentials` non verificato). `isCancellation` li distingue dal testo
  della `failureReason` («…webcredentials…»): nel secondo caso si va al browser invece di tacere.
- **CDN di Apple:** il simulatore restava con `webcredentials` negato perché leggeva l'AASA dalla CDN.
  Per questo in Debug c'è `?mode=developer` (`ARIA_ASSOCIATED_DOMAINS_MODE` in `AriaLite.xcconfig`) e
  `AriaLite.Debug.entitlements` contiene sia le righe normali sia quelle in modalità developer. **[in lavorazione]**
- **AASA:** contiene `webcredentials` per l'app iOS. `applinks` copre solo i link di accesso, non `/connectors/…`.
  Al ritorno https di `ASWebAuthenticationSession` basta `webcredentials`.

---

## 10. Test come specifica

Da `ConnectorConsentTests` e `ConnectorConnectCardTests`. Conviene riscriverli uguali su Android.

- L'annullamento dell'utente (e la cancellazione della coroutine) vale come annullamento: nessun errore.
- Un errore «app non associata al dominio» **non** è un annullamento: si passa al browser.
- Gli altri errori della sessione non sono annullamenti.
- Le dieci card del §3 sono Composio anche senza `mcp_url`. `maintainx` e `notion` (`https://mcp.notion.com/mcp`) no.
  `https://backend.composio.dev/...` sì, `http://backend.composio.dev/...` no.
- `/v1/me`: `membership { role, restricted }` si legge in modo tollerante. Se manca o ha una forma inattesa vale
  `null` (e quindi non si gestiscono i connettori).
- Card in chat: tiene solo le sorgenti https, non mostra il pulsante con `callerCan: "none"` o
  `state: "not_available"`, e usa `provider` come titolo se manca `label`.

---

## 11. Testi (en → it)

| Inglese (chiave) | Italiano |
|---|---|
| Finish signing in in the browser, then come back here. It works only if you're signed in to Aria on the web in that browser. | Completa l'accesso nel browser, poi torna qui. Funziona solo se in quel browser hai già fatto l'accesso ad Aria sul web. |
| Connected as %@ | Collegato come %@ |
| %@ connected | %@ collegato |
| Couldn't finish the sign-in. Start again. | Impossibile completare l'accesso. Ricomincia. |
| This sign-in link was already used. Start again. | Questo link di accesso è già stato usato. Ricomincia. |
| The connection service isn't reachable right now. Try again later. | Il servizio di collegamento non è raggiungibile. Riprova più tardi. |
| Your role isn't allowed to do this. Ask a company owner or admin. | Il tuo ruolo non consente questa operazione. Chiedi a un owner o admin dell'azienda. |
| This connector no longer exists. Pull to refresh the list. | Questo connettore non esiste più. Trascina in basso per aggiornare l'elenco. |
| Connect on the web | Collega dal web |

---

## 12. Aperti

- **`assetlinks.json` non pubblicato** (404 al 30/10/2026): senza questo file, su Android il ritorno https non arriva
  all'app.
- Auth Tab o Custom Tab + App Link: nessuno dei due è stato provato. Va scelto dopo un test sui dispositivi reali.
- Il comportamento di `inspect` quando il server non ha `platform_client_available` viene dal codice iOS (in quel
  caso si lascia decidere il server). Non è verificato contro il backend.
