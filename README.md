<!--
  README.md
  AriaLite

  Created by Giovanni Michele on 20/11/26.
-->

# AriaLite

App iOS e iPadOS di **AriA**, la piattaforma di manutenzione industriale con assistente AI. Un solo accesso via
email (link senza password, poi Face ID) e l'app si adatta a chi entra:

- **Manutentori**: chat con Aria (testo e voce), ordini di lavoro con cache locale e sincronizzazione offline,
  notifiche.
- **Admin e owner**: le sezioni della web app (asset, documenti, manutenzione, ordini d'acquisto, ricambi,
  Agent Studio, Marketplace, utenti, ruoli e diritti, consumi), mostrate secondo i diritti letti da `GET /v1/me`.

## Requisiti

- Xcode recente (il progetto è aggiornato con Xcode 27)
- iOS / iPadOS 18.0 o successivo, iPhone e iPad
- Swift con concorrenza "approachable" e isolamento di default su `MainActor`

## Avvio

```sh
git clone https://github.com/GiovanniMicheleNapoli23/AriA-LT.git
open AriA-LT/AriaLite/AriaLite.xcodeproj
```

Si compila e si avvia lo schema **AriaLite**. Senza configurazione l'app punta ai server di produzione
(`AriaLite/Config/AriaLite.xcconfig`).

Per usare altri host o la chiave del motore vocale si crea il file locale dei segreti, ignorato da git:

```sh
cd AriaLite/Config
cp Secrets.example.xcconfig Secrets.xcconfig
```

e si tolgono i `//` solo dalle chiavi da sovrascrivere. Negli xcconfig si scrivono solo gli host, mai `https://…`
(`//` inizia un commento).

## Struttura

```
AriaLite/
├── AriaLite/
│   ├── App/          avvio, AppDelegate, ContentView
│   ├── Shared/       backend e rete, login, chat, navigazione, onboarding, componenti comuni
│   ├── Maintainer/   ordini di lavoro, persistenza locale, notifiche del manutentore
│   ├── Admin/        una cartella per sezione admin
│   └── Localizable.xcstrings
├── AriaLiteTests/    unit test (Swift Testing)
├── AriaLiteUITests/  test UI contro il backend vero
├── Config/           xcconfig e modello dei segreti
└── scripts/          catalogo del Marketplace, test UI
```

Ogni funzionalità segue MVVM: `Model/`, `ViewModel/` (tutta la logica), `Views/` e `Components/` (viste senza
logica).

## Convenzioni

- **Lingue**: inglese (sorgente) e italiano in `Localizable.xcstrings`. Nell'interfaccia inglese si dice "site",
  non "plant"; i nomi nel codice e nelle API restano `plant`.
- **Testo**: solo gli stili di Dynamic Type, niente dimensioni fisse.
- **Colori**: rosso solo per errori e azioni distruttive; stati negativi o non risolti in grigio.
- **Nuovi file**: intestazione `Created by Giovanni Michele on GG/MM/AA.`
- **Commit**: uno per modifica, in inglese, divisi per argomento.

## Test

Gli unit test girano su un simulatore dedicato, non su quello che si usa a mano: azzerano e simulano la sessione,
e sul simulatore personale costringono a rifare l'accesso. Servono la firma del codice (il Portachiavi non
funziona con `CODE_SIGNING_ALLOWED=NO`).

```sh
xcodebuild test -project AriaLite/AriaLite.xcodeproj -scheme AriaLite \
  -destination 'platform=iOS Simulator,name=AriaLite Tests' -only-testing:AriaLiteTests
```

I test UI usano la sessione vera di un operatore, salvata fuori dal repository:

```sh
AriaLite/scripts/ui-tests.sh request operatore@azienda.it   # manda il link di accesso
AriaLite/scripts/ui-tests.sh login '<link o token>'         # salva la sessione (~7 giorni)
AriaLite/scripts/ui-tests.sh test                           # solo letture
AriaLite/scripts/ui-tests.sh test --write                   # anche i test che scrivono
```

## Catalogo del Marketplace

Il catalogo esiste solo nel frontend della web: l'app lo legge da un JSON nel bundle, da rigenerare quando la web
cambia.

```sh
cd AriaLite
node scripts/export-marketplace-catalog.mjs ~/Desktop/aria-web
```

Le traduzioni italiane stanno in `MarketplaceCatalog.it.json`; i testi senza traduzione restano in inglese.
