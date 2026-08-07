# Passi da seguire — mettere in servizio i percorsi

Procedura per accendere il servizio percorsi e vedere le distanze reali sull'iPhone.
Il piano e le ragioni stanno in [`linee-guida/10-percorsi-e-backend.md`](linee-guida/10-percorsi-e-backend.md);
il servizio in [`percorsi/`](percorsi). Qui ci sono solo le cose da **fare**, in ordine.

Segui i punti uno alla volta. Dove c'è scritto «deve rispondere», fermati e controlla
davvero: ogni verifica esiste perché saltandola il problema si scopre più tardi e peggio.

## Dove sei adesso

**Parti 1, 2 e 3 concluse.** Il servizio è in esercizio e l'app gira sull'iPhone con le
distanze reali. Verificato: `https://percorsi.pienocarburanti.com/v1/salute` risponde dai
dati mobili con certificato valido, il motore non è esposto (`/route` e `/table` danno 404),
e tutto riparte da solo dopo lo spegnimento notturno — Docker al login, motore col
`--restart`, API e tunnel come servizi.

Questo documento resta per **rifare la procedura da zero** (macchina nuova, reinstallazione)
e per i due inciampi d'ambiente in fondo, che sono la parte che nessuno indovina.

Quello che resta aperto non sta qui: i difetti noti sono nel registro
[`revisione/REVISIONE.md`](revisione/REVISIONE.md), sezione Z.

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

**6.** ✅ **Fatto.** Il dominio è **`pienocarburanti.com`**, comprato su Cloudflare il 7 agosto
2026. La zona DNS è già nell'account, quindi non c'è nessun nameserver da spostare.

Il servizio vivrà su **`percorsi.pienocarburanti.com`**. Tutti i comandi qui sotto lo
riportano già scritto: si copiano e si incollano così come sono.

**7.** ✅ **Fatto.** Vai avanti al punto 8.

> Se un domani cambi dominio, le occorrenze da aggiornare sono qui, in
> `percorsi/README.md`, in `linee-guida/10-percorsi-e-backend.md` e — l'unica nel codice — in
> `app/lib/state/app_state.dart`, alla costante `kBaseUrlPercorsi`.

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
cloudflared tunnel route dns pieno-percorsi percorsi.pienocarburanti.com
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
  - hostname: percorsi.pienocarburanti.com
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

**14.** Nel browser apri `https://percorsi.pienocarburanti.com/v1/salute`.
Deve rispondere `{"stato":"su",...}` con il lucchetto del certificato.

**15.** Torna al terminale e premi **Ctrl+C** per fermarlo.

## Renderlo permanente

**16.** Apri **PowerShell come amministratore**: premi `Win`, scrivi `powershell`, tasto
destro su *Windows PowerShell* → **Esegui come amministratore**. Nel titolo della finestra
deve comparire `Amministratore:`.

```powershell
cloudflared service install
```

**17.** Il servizio installato così **non parte**, e non è sfortuna: `cloudflared service
install` registra il servizio nudo, senza dirgli cosa eseguire. Lo si vede nel registro
eventi — `Cloudflared service arguments: [cloudflared.exe]`, senza `tunnel run` — e il
servizio muore all'istante con `exitCode 1067`. Succede quando il tunnel è **gestito
localmente** con `config.yml`, invece che con un token preso dal pannello.

Servono due cose. Primo, la configurazione dove la cerca l'account di sistema:

```powershell
$d = "C:\Windows\System32\config\systemprofile\.cloudflared"
New-Item -ItemType Directory -Force -Path $d
Copy-Item "$env:USERPROFILE\.cloudflared\config.yml" $d -Force
Copy-Item "$env:USERPROFILE\.cloudflared\cert.pem" $d -Force
Copy-Item "$env:USERPROFILE\.cloudflared\41bcf1b4-0bdb-4be4-977d-a5967363a475.json" $d -Force
```

Secondo, dire al servizio quale comando eseguire. **Una riga alla volta**: se il testo si
spezza incollandolo, nel registro finisce un a capo e il servizio non parte più.

```powershell
$p = "HKLM:\SYSTEM\CurrentControlSet\Services\Cloudflared"
$e = '"C:\Program Files (x86)\cloudflared\cloudflared.exe"'
$c = '"C:\Windows\System32\config\systemprofile\.cloudflared\config.yml"'
$img = "$e --config $c tunnel run pieno-percorsi"
Set-ItemProperty -Path $p -Name ImagePath -Value $img
Start-Service cloudflared
Get-Service cloudflared
```

Devi vedere `Running` e `StartType: Automatic`.

> Se il servizio resta bloccato su `StopPending`, cloudflared non sta chiudendo le sue
> connessioni. Si termina a forza: `Get-CimInstance Win32_Service -Filter "Name='Cloudflared'"`
> per il PID, poi `Stop-Process -Id <PID> -Force`, aspetta dieci secondi e `Start-Service`.

Poi apri nel browser `https://percorsi.pienocarburanti.com/v1/salute`: deve rispondere
`{"stato":"su",...}` con il lucchetto.

## Le tre verifiche finali

**18.** Prendi il telefono e **spegni il Wi-Fi**. Devi stare sui dati mobili: è l'unico modo
di provare che si arrivi davvero da fuori casa.

**19.** Apri `https://percorsi.pienocarburanti.com/v1/salute`
→ deve rispondere `{"stato":"su",...}`.

**20.** Apri `https://percorsi.pienocarburanti.com/route/v1/driving/9.19,45.46;9.22,45.47`
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

**27.** Avvia l'app. Il dominio è già il valore predefinito nel codice, quindi non serve
nessun flag:

```bash
flutter run
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

**Le build non hanno bisogno di flag.** L'indirizzo `https://percorsi.pienocarburanti.com` è
il valore predefinito nel codice (`kBaseUrlPercorsi` in `app/lib/state/app_state.dart`),
quindi basta:

```bash
flutter build ipa
```

È voluto: se il dominio fosse stato solo un flag da riga di comando, dimenticarlo una volta
avrebbe prodotto un'app che non chiede mai le distanze reali — e non se ne sarebbe accorto
nessuno, perché ripiegare sulla stima è silenzioso e legittimo.

Il `--dart-define` resta per le prove, quando serve puntare altrove.

**Tre voci ancora da definire** in [`rilascio/privacy.md`](rilascio/privacy.md), che gli store
pretendono prima della pubblicazione:

- titolare del trattamento (nome e cognome);
- email di contatto;
- indirizzo pubblico dove pubblichi l'informativa — ora che hai un dominio, mettila lì.

---

# Se qualcosa non va

| Sintomo | Dove guardare |
| --- | --- |
| `"stato":"degradato"` ma Docker è acceso | Windows si è ripreso la porta 5000 — vedi sotto |
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

## Quando Windows si riprende la porta 5000

Sintomo: Docker è acceso, il container risulta `Up`, ma l'API dice `"stato":"degradato"`.
Prova del nove — questa riga deve mostrare `127.0.0.1:5000->5000/tcp`:

```bash
docker ps --filter name=pieno-osrm --format '{{.Ports}}'
```

Se mostra solo `5000/tcp`, la porta non è pubblicata. Hyper-V si riserva intervalli di
porte che **ricalcola a ogni accensione**, e ogni tanto ci finisce dentro la 5000.

Rimedio definitivo, una volta sola, da **PowerShell come amministratore**:

```powershell
net stop winnat
netsh int ipv4 add excludedportrange protocol=tcp startport=5000 numberofports=1 store=persistent
net start winnat
```

Poi ricrea il container (Git Bash, dalla radice del progetto):

```bash
export MSYS_NO_PATHCONV=1
docker rm -f pieno-osrm
docker run -d --name pieno-osrm --restart unless-stopped \
  -v "$(cat percorsi/.grafo-attivo):/data" -p 127.0.0.1:5000:5000 \
  ghcr.io/project-osrm/osrm-backend:latest \
  osrm-routed --algorithm mld --max-table-size 1000 --max-matching-size 100 /data/italy-latest.osrm
```

Per controllare che la riserva sia nostra:

```powershell
netsh interface ipv4 show excludedportrange protocol=tcp
```

Deve comparire una riga `5000  5000` con un **asterisco**: significa esclusione amministrata,
cioè assegnata a noi e non più riassegnabile da Windows.

> Questa riserva è già stata fatta su questa macchina il 7 agosto 2026. È scritta qui perché
> sopravviva a una reinstallazione, e perché il sintomo — «Docker è acceso ma il motore non
> c'è» — non porta da nessuna parte se non si sa dove guardare.
