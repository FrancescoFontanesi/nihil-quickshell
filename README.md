# Nihil HUD

Configurazione [Quickshell](https://quickshell.org/) per Hyprland che costruisce un'interfaccia HUD monocromatica: cornici ai bordi dello schermo, indicatori di sistema, workspace, pannello GPT, controlli di sessione e launcher applicazioni.

Il progetto è scritto in QML e usa direttamente i servizi reattivi di Quickshell. Batteria, volume e workspace non richiedono processi di polling periodici.

## Indice

- [Caratteristiche](#caratteristiche)
- [Dipendenze](#dipendenze)
- [Installazione](#installazione)
- [Integrazione con Hyprland](#integrazione-con-hyprland)
- [Componenti](#componenti)
  - [Il layout dei lati](#il-layout-dei-lati)
  - [L'HUD per GPT](#lhud-per-gpt)
  - [L'HUD della batteria, del volume e della luminosità](#lhud-della-batteria-del-volume-e-della-luminosità)
  - [L'HUD dell'orologio e dei workspace](#lhud-dellorologio-e-dei-workspace)
  - [L'HUD del launcher](#lhud-del-launcher)
- [Struttura del repository](#struttura-del-repository)
- [Personalizzazione](#personalizzazione)
- [Risoluzione dei problemi](#risoluzione-dei-problemi)

## Caratteristiche

- Cornice PNG indipendente sui quattro lati dello schermo.
- Pannelli layer-shell sovrapposti alle finestre senza alterarne il layout.
- HUD GPT animato, collegato a un wrapper esterno.
- Controlli per sospensione, riavvio e spegnimento.
- Batteria tramite UPower e volume tramite PipeWire.
- Workspace aggiornati dagli eventi Hyprland.
- Luminosità aggiornata tramite un file osservato da Quickshell.
- Launcher con indicizzazione delle desktop entry, ricerca, navigazione da tastiera e avvio applicazioni.

## Dipendenze

### Essenziali

| Dipendenza | Utilizzo |
| --- | --- |
| Quickshell | Runtime QML e gestione delle `PanelWindow` |
| Hyprland | Compositor, layer-shell, eventi workspace e shortcut globali |
| Qt 6 / QtQuick / QtQml | Componenti e animazioni dell'interfaccia |
| PipeWire + WirePlumber | Stato del sink audio predefinito |
| UPower | Percentuale e stato di carica della batteria |
| `brightnessctl` | Incremento e decremento della luminosità |
| `pamixer` | Tasti volume configurati in `hyprland.conf` |
| PulseAudio tools (`pactl`) | Toggle del microfono configurato in `hyprland.conf` |
| Bash, GNU coreutils e `awk` | Script della luminosità |

La build di Quickshell deve includere questi moduli QML:

```text
Quickshell
Quickshell.Hyprland
Quickshell.Io
Quickshell.Services.Pipewire
Quickshell.Services.UPower
Quickshell.Wayland
Quickshell.Widgets
```

### Opzionali

| Dipendenza | Utilizzo |
| --- | --- |
| Wrapper ChatGPT esterno | Finestra controllata da `ChatGPTHud.qml` tramite `--toggle` |
| `jq` | Solo per lo script legacy `scripts/battery.sh`; l'HUD usa direttamente UPower |
| `grim`, `slurp`, `wl-copy` | Shortcut per gli screenshot presenti nel file Hyprland di esempio |
| Font monospace | Testi del launcher e degli indicatori |

I pulsanti di sessione usano `systemctl`, quindi richiedono un sistema con systemd.

## Installazione

Clona il repository nel percorso atteso da `hyprland.conf`:

```bash
mkdir -p ~/.config/quickshell
git clone https://github.com/FrancescoFontanesi/nihil.git ~/.config/quickshell/nihil
chmod +x ~/.config/quickshell/nihil/scripts/*.sh
mkdir -p ~/.config/quickshell/nihil/tmp
```

Avvio manuale per la prima verifica:

```bash
quickshell -p ~/.config/quickshell/nihil/
```

Prima dell'uso su un altro sistema, modifica i percorsi assoluti descritti in [Personalizzazione](#personalizzazione).

## Integrazione con Hyprland

Le seguenti righe sono quelle attualmente usate in `hyprland.conf`. Nel setup originale il file si trova in `~/.config/hypr/hyprland.conf`.

> Nota: `hyprland.conf` non è incluso in questo repository; i blocchi seguenti sono pronti da copiare nel proprio file.

### Avvio automatico

Righe 37 e 39 del file originale:

```ini
exec-once = quickshell -p ~/.config/quickshell/nihil/
exec-once = /home/nihil/Extra/Chatgpt-PyGObject/chatgpt-wrapper --background
```

La seconda riga serve solo per l'HUD GPT e deve essere adattata alla posizione del proprio wrapper.

### Shortcut globali Quickshell

Righe 178, 186 e 187 del file originale:

```ini
$mainMod = SUPER

bind = $mainMod, Escape, global, lock:toggle
bind = $mainMod, M, global, hud:toggle
bind = SUPER_L, SPACE, global, launcher:toggle
```

Il formato è `global, appid:name` e corrisponde ai `GlobalShortcut` dichiarati nei componenti QML:

| Combinazione | Target Quickshell | Componente |
| --- | --- | --- |
| `SUPER + Escape` | `lock:toggle` | `modules/widgets/LockHud.qml` |
| `SUPER + M` | `hud:toggle` | `modules/widgets/ChatGPTHud.qml` |
| `SUPER + Space` | `launcher:toggle` | `modules/launcher/LauncherHud.qml` |

### Regole per il wrapper GPT

Righe 193–195 del file originale:

```ini
windowrulev2 = float, class:^(chatgpt-wrapper)$
windowrulev2 = size 794 1286,, class:^(chatgpt-wrapper)$
windowrulev2 = move 78 74, class:^(chatgpt-wrapper)$
```

### Volume e luminosità

Righe 253–260 del file originale:

```ini
bind = ,122, exec, pamixer --decrease 5
bind = ,123, exec, pamixer --increase 5
bind = ,121, exec, pamixer --toggle-mute
bind = ,XF86AudioMicMute, exec, pactl set-source-mute @DEFAULT_SOURCE@ toggle

bind = ,232, exec, ~/.config/hypr/scripts/decrement_brightness.sh
bind = ,233, exec, ~/.config/hypr/scripts/increment_brightness.sh
```

Il widget volume rileva automaticamente i cambiamenti tramite PipeWire. Gli script della luminosità devono aggiornare `tmp/brightness_percent`; è possibile copiarli o collegarli nella directory degli script Hyprland:

```bash
mkdir -p ~/.config/hypr/scripts
ln -s ~/.config/quickshell/nihil/scripts/decrement_brightness.sh ~/.config/hypr/scripts/decrement_brightness.sh
ln -s ~/.config/quickshell/nihil/scripts/increment_brightness.sh ~/.config/hypr/scripts/increment_brightness.sh
```

## Componenti

### Il layout dei lati

File principali:

- `modules/layout/EdgeOverlayLayout.qml`
- `modules/layout/EdgeStrip.qml`
- `assets/top.png`, `assets/bottom.png`, `assets/left.png`, `assets/right.png`

`EdgeOverlayLayout` crea quattro `PanelWindow`, riserva lo spazio configurato con `exclusiveZone` e disegna i PNG sui rispettivi bordi. `EdgeStrip` applica l'offset specifico del lato mantenendo la finestra click-through.

#### Screenshot

Percorso previsto: `docs/screenshots/layout-lati.png`

<!-- Quando lo screenshot è disponibile, rimuovere i delimitatori del commento:
![Layout HUD sui quattro lati](docs/screenshots/layout-lati.png)
-->

### L'HUD per GPT

File principali:

- `modules/widgets/ChatGPTHud.qml`
- `modules/widgets/LockHud.qml`
- `modules/widgets/HudLockButton.qml`

Con `SUPER + M`, `ChatGPTHud` anima il pannello sinistro e invoca il wrapper configurato in `shell.qml` con l'argomento `--toggle`. Il pannello si richiude al cambio workspace. Sul lato opposto, `SUPER + Escape` mostra i controlli di sospensione, riavvio e spegnimento.

#### Screenshot

Percorso previsto: `docs/screenshots/hud-gpt.png`

<!-- Quando lo screenshot è disponibile, rimuovere i delimitatori del commento:
![HUD GPT e controlli laterali](docs/screenshots/hud-gpt.png)
-->

### L'HUD della batteria, del volume e della luminosità

File principali:

- `modules/widgets/HudBattery.qml`
- `modules/widgets/HudVolumeBar.qml`
- `modules/widgets/HudbrightnessBar.qml`
- `scripts/increment_brightness.sh`
- `scripts/decrement_brightness.sh`

I tre indicatori sono posizionati nella barra inferiore:

- La batteria legge percentuale e alimentazione direttamente da UPower.
- Il volume osserva il sink predefinito tramite PipeWire e segnala lo stato mute.
- La luminosità osserva `tmp/brightness_percent` con `FileView`, senza mantenere un processo `tail` attivo.

#### Screenshot

Percorso previsto: `docs/screenshots/hud-stato-sistema.png`

<!-- Quando lo screenshot è disponibile, rimuovere i delimitatori del commento:
![HUD batteria, volume e luminosità](docs/screenshots/hud-stato-sistema.png)
-->

### L'HUD dell'orologio e dei workspace

File principali:

- `modules/widgets/HudClock.qml`
- `modules/widgets/HudWorkSpaces.qml`

La barra superiore mostra ora, data e dieci workspace. L'indicatore distingue workspace attivo e occupato; gli aggiornamenti arrivano dagli eventi Hyprland e non da processi `hyprctl` periodici.

#### Screenshot

Percorso previsto: `docs/screenshots/hud-orologio-workspaces.png`

<!-- Quando lo screenshot è disponibile, rimuovere i delimitatori del commento:
![HUD orologio e workspace](docs/screenshots/hud-orologio-workspaces.png)
-->

### L'HUD del launcher

File principali:

- `modules/launcher/LauncherHud.qml`
- `assets/wofi.png`

`SUPER + Space` apre il launcher e assegna immediatamente il focus alla ricerca. Le applicazioni provengono da `DesktopEntries.applications`; i risultati vengono ordinati per pertinenza e avviati tramite la relativa desktop entry.

Controlli disponibili:

| Tasto | Azione |
| --- | --- |
| Testo | Filtra le applicazioni indicizzate |
| `↑` / `↓` | Cambia selezione |
| `Page Up` / `Page Down` | Scorre una pagina |
| `Tab` / `Shift + Tab` | Selezione successiva o precedente |
| `Ctrl + N` / `Ctrl + P` | Selezione successiva o precedente |
| `Enter` | Avvia l'applicazione selezionata |
| `Escape` | Chiude il launcher |

#### Screenshot

Percorso previsto: `docs/screenshots/hud-launcher.png`

<!-- Quando lo screenshot è disponibile, rimuovere i delimitatori del commento:
![Launcher applicazioni](docs/screenshots/hud-launcher.png)
-->

## Struttura del repository

```text
.
├── assets/                 # Cornici e icone PNG
├── docs/screenshots/       # Screenshot usati dal README
├── modules/
│   ├── launcher/           # Launcher applicazioni
│   ├── layout/             # Finestre e strisce laterali
│   └── widgets/            # HUD e indicatori
├── scripts/                # Helper per luminosità e batteria legacy
├── shell.qml               # Entry point Quickshell
└── README.md
```

## Personalizzazione

Questi valori dipendono dal sistema originale e devono essere controllati dopo il clone:

- `shell.qml`: percorso del wrapper GPT e geometrie delle `PanelWindow`.
- `scripts/increment_brightness.sh` e `scripts/decrement_brightness.sh`: variabile `OUTFILE` e classe del dispositivo `BACKLIGHT`.
- `modules/widgets/HudBattery.qml`: UPower seleziona automaticamente il display device.
- `modules/layout/EdgeOverlayLayout.qml`: spessore, margini e posizione degli indicatori.
- `modules/launcher/LauncherHud.qml`: dimensioni, numero massimo di risultati e asset di sfondo.

Gli asset laterali inclusi sono progettati per il layout originale 2160 × 1440; altre risoluzioni possono richiedere l'adattamento delle geometrie in `shell.qml` e `EdgeOverlayLayout.qml`.

## Risoluzione dei problemi

### Quickshell non parte

```bash
quickshell -p ~/.config/quickshell/nihil/
```

Controlla l'output e verifica che tutti i moduli QML elencati nelle dipendenze siano disponibili.

### Lo shortcut non apre un HUD

Controlla la registrazione delle scorciatoie:

```bash
hyprctl globalshortcuts
```

Devono comparire `hud:toggle`, `lock:toggle` e `launcher:toggle`. Dopo una modifica a `hyprland.conf`, esegui `hyprctl reload`.

### Il launcher non riceve input

Verifica che `LauncherHud.qml` assegni `WlrKeyboardFocus.Exclusive` durante l'apertura e che non siano presenti altri focus grab concorrenti.

### La luminosità non si aggiorna

Controlla il file osservato:

```bash
cat ~/.config/quickshell/nihil/tmp/brightness_percent
```

Se non esiste, esegui uno degli script della luminosità e verifica `BACKLIGHT` e `OUTFILE`.

### Log runtime

```bash
qs -p ~/.config/quickshell/nihil log --no-color
```
