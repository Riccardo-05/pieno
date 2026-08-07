# Passi da seguire — mettere in servizio i percorsi

Procedura per accendere il servizio percorsi e vedere le distanze reali sull'iPhone.
Il piano e le ragioni stanno in [`linee-guida/10-percorsi-e-backend.md`](linee-guida/10-percorsi-e-backend.md);
il servizio in [`percorsi/`](percorsi). Qui ci sono solo le cose da **fare**, in ordine.

Segui i punti uno alla volta. Dove c'è scritto «deve rispondere», fermati e controlla
davvero: ogni verifica esiste perché saltandola il problema si scopre più tardi e peggio.

## Dove sei adesso

Già fatto e verificato:

- il motore OSRM gira in Docker, raggiungibile **solo** da dentro la macchina;
- l'API risponde sulle tre rotte, con cache, limite di frequenza e nessun log delle posizioni;
- l'app sa parlarci, con tetto di due secondi e ripiego dichiarato;
- le due attività pianificate sono registrate (`Pieno - API percorsi`, `Pieno - Ricostruzione grafo`);
- `cloudflared` è installato.

Manca: il dominio, il tunnel, e vedere l'app funzionare sul telefono.

**Due macchine.** Il **PC Windows** (`Magicnuc`, 192.168.1.254) fa il server: parti 1 e 2.
Il **Mac** serve solo a mandare l'app sull'iPhone: parte 3.

> **Docker parte al login, non all'accensione.** Hai scelto di fare il login a mano ogni
> mattina. Se una volta te ne dimentichi, l'app non si rompe: mostra le distanze stimate e
> lo dichiara, come fa ogni notte fra le 02:00 e le 08:00. Perdi precisione, non l'app.

---

# Parte 1 · PC Windows — riavvio e verifica

**1.** Riavvia il PC.

**2.** Fai il login a Windows.

**3.** Aspetta **2–3 minuti** senza fare niente: Docker Desktop parte dopo il login e ci mette
un po' a svegliare il motore.

**4.** Apri **Git Bash** (premi `Win`, scrivi `git bash`, Invio) e incolla:

```bash
curl -s localhost:8080/v1/salute
```

**5.** Leggi la risposta:

| Cosa leggi | Cosa fai |
| --- | --- |
| `"stato":"su"` | vai al punto 6 |
| `"stato":"degradato"` | Docker non è ancora pronto: aspetta un minuto e ripeti il punto 4 |
| nessuna risposta | l'attività pianificata non parte: **fermati** |

Non proseguire senza `"stato":"su"`. Esporre al mondo un servizio che non riparte da solo
significa scoprire il guasto fra due settimane, di notte.

---

# Parte 2 · PC Windows — dominio e tunnel

## Il dominio

**6.** Vai su **dash.cloudflare.com**. Crea l'account se non ce l'hai.

**7.** Menù a sinistra → **Domain Registration** → **Register Domain**. Cerca un nome libero,
**corto e facile da scrivere al telefono** (finirà in `percorsi.TUODOMINIO`, e lo digiterai a
mano nelle verifiche finali). Compra: circa 10 € l'anno, al costo.

Da qui in avanti, dove è scritto `TUODOMINIO`, metti quello che hai comprato.

> Non serve comprarlo per forza qui: un dominio che hai già altrove va bene, ma va spostata
> la gestione DNS su Cloudflare cambiando i nameserver — e se su quel dominio hai una casella
> email devi prima controllare che i record **MX** siano stati importati, altrimenti l'email
> smette di arrivare. Comprarne uno nuovo qui evita tutto questo.

## Il tunnel

**8.** Apri una finestra **nuova** di Git Bash. Nuova per forza: `cloudflared` è stato
installato di recente e le finestre già aperte non lo trovano.

```bash
cloudflared --version
```

Deve stampare `cloudflared version 2026.7.3` o successiva. Se dice `command not found`, nei
punti seguenti scrivi `"/c/Program Files (x86)/cloudflared/cloudflared.exe"` al posto di
`cloudflared`.

**9.** Collega cloudflared al tuo account:

```bash
cloudflared tunnel login
```

Si apre il browser: seleziona il dominio e clicca **Authorize**.

**10.** Crea il tunnel:

```bash
cloudflared tunnel create pieno-percorsi
```

Stampa `Created tunnel pieno-percorsi with id a1b2c3d4-e5f6-...`.
**Copia quell'identificativo lungo**: serve al punto 12.

**11.** Assegna il nome pubblico:

```bash
cloudflared tunnel route dns pieno-percorsi percorsi.TUODOMINIO
```

**12.** Scrivi la configurazione:

```bash
notepad "$USERPROFILE/.cloudflared/config.yml"
```

Blocco note chiede se creare il file: **Sì**. Incolla questo, sostituendo le due parti in
maiuscolo, poi salva e chiudi:

```yaml
tunnel: pieno-percorsi
credentials-file: C:\Users\rikyr\.cloudflared\INCOLLA-QUI-IDENTIFICATIVO.json

ingress:
  - hostname: percorsi.TUODOMINIO
    service: http://127.0.0.1:8080
  - service: http_status:404
```

> **La riga `service` deve dire 8080.** La 8080 è l'API di Pieno: ha la cache, il limite di
> frequenza, e non registra nessuna posizione. La 5000 è il motore nudo — esporlo
> significherebbe regalare a chiunque un calcolatore di percorsi senza limiti, e senza
> nessuna delle protezioni scritte apposta.

**13.** Prova il tunnel prima di renderlo permanente:

```bash
cloudflared tunnel run pieno-percorsi
```

Lascia la finestra aperta. Deve stampare righe con `Registered tunnel connection`.

**14.** Nel browser apri `https://percorsi.TUODOMINIO/v1/salute`.
Deve rispondere `{"stato":"su",...}` con il lucchetto del certificato.

**15.** Torna al terminale e premi **Ctrl+C** per fermarlo.

## Renderlo permanente

**16.** Apri **PowerShell come amministratore**: premi `Win`, scrivi `powershell`, tasto
destro su *Windows PowerShell* → **Esegui come amministratore**. Nel titolo della finestra
deve comparire `Amministratore:`.

```powershell
cloudflared service install
Get-Service cloudflared
```

Devi vedere `Status: Running` e `StartType: Automatic`.

**17.** Riapri nel browser `https://percorsi.TUODOMINIO/v1/salute`.

Se **non** risponde più, il servizio gira con l'account di sistema e cerca la configurazione
in un'altra cartella. Rimedio, sempre in PowerShell amministratore:

```powershell
$d = "C:\Windows\System32\config\systemprofile\.cloudflared"
New-Item -ItemType Directory -Force -Path $d
Copy-Item "$env:USERPROFILE\.cloudflared\*" $d -Force
Restart-Service cloudflared
```

Poi riprova.

## Le tre verifiche finali

**18.** Prendi il telefono e **spegni il Wi-Fi**. Devi stare sui dati mobili: è l'unico modo
di provare che si arrivi davvero da fuori casa.

**19.** Apri `https://percorsi.TUODOMINIO/v1/salute`
→ deve rispondere `{"stato":"su",...}`.

**20.** Apri `https://percorsi.TUODOMINIO/route/v1/driving/9.19,45.46;9.22,45.47`
→ deve dare **errore o pagina non trovata**.

Se invece risponde con dei numeri, il tunnel sta esponendo il motore: torna al punto 12 e
correggi la porta.

**21.** Riavvia il PC un'ultima volta, **fai il login**, aspetta 3 minuti, e ripeti il punto
19 dal telefono. Se risponde senza che tu abbia toccato niente, il PC Windows è finito e non
lo apri più: da qui in poi fa il server e basta.

---

# Parte 3 · Mac e iPhone

Perché il Mac: l'app va su iPhone, e per firmarla serve Xcode.

Perché **dopo** il dominio: iOS rifiuta le connessioni non cifrate. Con l'indirizzo `https`
del tunnel non c'è nulla da configurare; provando in rete locale su `http` bisognerebbe
indebolire l'app con un'eccezione nell'`Info.plist`, per una prova soltanto.

## Preparare il Mac

**22.** Prendi il codice:

```bash
git clone https://github.com/Riccardo-05/pieno.git
cd pieno/app
flutter pub get
```

Se il repository ce l'hai già sul Mac, basta `git pull` e `flutter pub get`.

**23.** Controlla l'ambiente:

```bash
flutter doctor
```

Devono risultare a posto **Xcode** e **CocoaPods**. Se `flutter doctor` si lamenta, risolvi
quello prima di proseguire: sono le sole due cose che servono.

## Mandare l'app sull'iPhone

**24.** Collega l'iPhone via cavo, sbloccalo, e rispondi **Autorizza** al messaggio «Vuoi
autorizzare questo computer?».

**25.** Verifica che il Mac lo veda:

```bash
flutter devices
```

Il tuo iPhone deve comparire nell'elenco.

**26.** Imposta la firma. Apri `ios/Runner.xcworkspace` con Xcode, scheda
**Signing & Capabilities**, e scegli il tuo Apple ID come *Team*. Basta un account gratuito:
la firma dura sette giorni, più che sufficiente per provare.

**27.** Avvia l'app, mettendo il tuo dominio:

```bash
flutter run --dart-define=PIENO_PERCORSI=https://percorsi.TUODOMINIO
```

**28.** La prima volta l'iPhone rifiuta di aprirla. Vai in **Impostazioni → Generali → VPN e
gestione dispositivo**, tocca il tuo certificato di sviluppatore e scegli **Autorizza**.

## Cosa devi vedere

**29.** Concedi il permesso di posizione quando l'app lo chiede: senza, non c'è nessuna
distanza da calcolare.

**30.** Guarda la scheda dell'impianto principale:

| Deve dire | Non deve dire |
| --- | --- |
| **«a 4,7 km · 11 min»** | «a 4,2 km in linea d'aria» |

E poi:

- i chilometri sono **più alti** di prima — la strada gira, la linea d'aria no;
- il **risparmio in euro è più basso**, e su qualche impianto la pastiglia sparisce.
  **È giusto così**: è l'app che smette di promettere risparmi che non esistono.

**31.** La prova del ripiego, che è la situazione di ogni notte. Sul PC Windows, da
PowerShell amministratore:

```powershell
Stop-ScheduledTask -TaskName "Pieno - API percorsi"
```

Sull'iPhone cambia carburante o ricarica. Entro **due secondi** la distanza deve tornare a
«in linea d'aria», senza rotelline infinite e senza schermate vuote. Poi lascia l'app aperta
dieci minuti: non deve continuare a bussare.

Rimetti tutto a posto:

```powershell
Start-ScheduledTask -TaskName "Pieno - API percorsi"
```

**32.** Impostazioni → **Rifornimento** → **Consumo medio**. Portalo da 7,0 a 12,0 l/100 km:
i risparmi devono calare ancora. Chiudi e riapri l'app: il valore deve essere rimasto.

---

# Da ricordare, dopo

**Ogni build dell'app va fatta con il dominio:**

```bash
flutter build ipa --dart-define=PIENO_PERCORSI=https://percorsi.TUODOMINIO
```

Senza quel `--dart-define` l'app non contatta nulla e resta sulla stima. Non si rompe, ma non
fa quello per cui esiste il servizio.

**Tre voci ancora da definire** in [`rilascio/privacy.md`](rilascio/privacy.md), che gli store
pretendono prima della pubblicazione:

- titolare del trattamento (nome e cognome);
- email di contatto;
- indirizzo pubblico dove pubblichi l'informativa — ora che hai un dominio, mettila lì.

---

# Se qualcosa non va

| Sintomo | Dove guardare |
| --- | --- |
| `"stato":"degradato"` | Docker non è partito. Aprilo e aspetta un minuto |
| Nessuna risposta sulla 8080 | `Get-ScheduledTask -TaskName "Pieno*"`, poi `Start-ScheduledTask -TaskName "Pieno - API percorsi"` |
| Il dominio non risponde | `Get-Service cloudflared`; se non è `Running`, vedi il punto 17 |
| L'app mostra sempre la stima | hai lanciato `flutter run` senza `--dart-define`, oppure il servizio non risponde entro due secondi |
| Distanze assurde su qualche impianto | è il fattore stradale: su 1 impianto su 100 vale 9–10, tipico dei distributori in autostrada |

Comandi utili sul PC Windows:

```bash
curl -s localhost:8080/v1/salute          # stato, versione del grafo, uptime, cache
docker ps --filter name=pieno-osrm        # il motore è su?
```

```powershell
Get-ScheduledTask -TaskName "Pieno*" | Format-Table TaskName, State
Get-Service cloudflared
```

Il registro della ricostruzione mensile finisce in `percorsi\log\ricostruzione-AAAA-MM-GG.log`.
