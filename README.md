# Neutral Zone Trap

Aplikace pro iPhone, iPadOS a macOS, která přijímá, vizualizuje a analyzuje
telemetrická data hokejového hráče. Vznikla jako bakalářská práce na FEL ČVUT.

Aplikace umožňuje:

- příjem simulovaných polohových dat hráče v reálném čase přes UDP,
- zobrazení aktuální polohy na 2D (případně 3D) modelu hokejového kluziště,
- vykreslení trajektorie pohybu a heatmapy,
- výpočet základních statistik (ujetá vzdálenost, rychlost),
- záznam a opětovné přehrávání zaznamenaného pohybu po časové ose,
- ukládání a import záznamů ve vlastním formátu `.nzt`.

Uživatelský návod je v samostatném dokumentu [`USER_GUIDE.md`](USER_GUIDE.md).

## Stáhnout

<!-- DOWNLOAD-START -->
[![Stáhnout DMG](https://img.shields.io/badge/Stáhnout-DMG-blue?style=for-the-badge&logo=apple)](https://github.com/sdrda/NeutralZoneTrap/releases/latest/download/Neutral-Zone-Trap.dmg)

**Aktuální verze:** [](https://github.com/sdrda/NeutralZoneTrap/releases/tag/v1.0.1) — commit  (2026-05-22 06:43 UTC)

Přímý odkaz vždy ukazuje na nejnovější build: https://github.com/sdrda/NeutralZoneTrap/releases/latest/download/Neutral-Zone-Trap.dmg
<!-- DOWNLOAD-END -->

Jelikož aplikace není podepsána certifikátem, je spuštění nutné povolit v nastavení **Soukromí a zabezpečení**.

## Požadavky

- macOS 26.2 nebo novější (Apple silicon)
- Xcode 26.2 a Swift 6.0
- Pro simulaci telemetrie libovolný UDP klient (Python, `nc`, …)

## Build a spuštění

```bash
git clone <repo-url>
cd "Neutral Zone Trap"
xed .
```

V Xcodu zvolte schéma **Neutral Zone Trap** a libovolné podporované zařízení. Aplikace
naslouchá na UDP portu **12345**. Hodnota portu je centralizovaná
v `Neutral Zone Trap/Application/AppConfig.swift` (`AppConfig.udpPort`)
— pro jiný port stačí změnit konstantu a rebuildnout.

Pro spuštění s CloudKit je nutný placený Apple Developer účet a je pravděpodobné, že budete muset vytvořit vlastní iCloud kontajner.

## Simulátor telemetrie

Aplikace očekává pakety o pevné velikosti **32 bajtů** v little-endian kódování:

| offset | délka | typ      | význam                              |
|-------:|------:|----------|-------------------------------------|
|      0 |     8 | Double   | x-ová souřadnice v metrech          |
|      8 |     8 | Double   | y-ová souřadnice v metrech          |
|     16 |     8 | UInt64   | hardware ID senzoru                 |
|     24 |     8 | Double   | UNIX timestamp (sekundy)            |

Souřadný systém má počátek uprostřed plochy, rozměry podle normy IIHF
(60 m × 30 m, viz `IIHFRinkConfiguration`).

Minimální simulátor v Pythonu (little-endian, `ddQd` = 32 B):

```python
import socket, struct, time, math

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sensor_id = 1
start = time.time()
while True:
    t = time.time() - start
    x = 20.0 * math.sin(0.5 * t)
    y = 10.0 * math.sin(0.3 * t)
    packet = struct.pack("<ddQd", x, y, sensor_id, time.time())
    sock.sendto(packet, ("127.0.0.1", 12345))
    time.sleep(0.05)
```

## Architektura

Aplikace používá **architekturu postavenou na Observation
frameworku** (iOS 17+ / macOS 14+). Místo explicitní MVVM ViewModel vrstvy
slouží **`@Observable` modelové třídy** — services, stores a coordinators
— jako reactive observation layer. Views je přímo pozorují přes
`@Environment`.

### Struktura projektu

```
Neutral Zone Trap/
├── Neutral Zone Trap/               aplikační kód
│   ├── Neutral_Zone_TrapApp.swift   @main entrypoint
│   ├── ContentView.swift            tab view + root ErrorRouter injection
│   ├── Application/
│   │   ├── AppConfig.swift          app-level konstanty (udpPort, …)
│   │   ├── Protocols/               service kontrakty (PacketReceiver,
│   │   │                            RecordingControl, PlaybackControl,
│   │   │                            PositionStoreReading/Writing,
│   │   │                            SessionLoading/Snapshotting,
│   │   │                            StatisticsIngest, StreamProcessing)
│   │   ├── Services/                use-case orchestrátory
│   │   │                            (Recorder actor, Playback,
│   │   │                            SensorStreamProcessor,
│   │   │                            SessionFileManager, Statistics)
│   │   └── State/                   AppMode + AppModeState,
│   │                                SensorPositionStore
│   ├── Domain/
│   │   ├── Models/                  Session, SensorTrack, SensorPosition,
│   │   │                            SensorHardwareID, Session+Analytics
│   │   ├── Services/                SensorMetrics (pure helpers)
│   │   └── Errors/                  OnsideError
│   ├── Persistence/Entities/        SwiftData @Model třídy
│   │                                (Player, PlayerGroup, Sensor)
│   ├── Infrastructure/              adaptéry pro I/O a externí formáty
│   │   ├── Networking/              UDPReceiver (actor), PacketReceiver
│   │   │                            protokol, PositionParser
│   │   ├── Files/                   NZTDocument (FileDocument)
│   │   └── Logging/                 BenchmarkLogger, Logger+App
│   └── Presentation/
│       ├── Components/RinkView/     ModeIndicator, PlayersInspector,
│       │                            RinkControlPanel, RinkViewToolbar
│       ├── Configuration/           RinkConfiguration, IIHFRinkConfiguration,
│       │                            EnvironmentValues+LiveSource
│       ├── Extensions/              Color+Hex, Binding+Optional
│       ├── Forms/                   AddPlayerForm, AddGroupForm, AddSensorForm
│       ├── Menu/                    AppTab, FocusedValues,
│       │                            Commands/ (Tab/Session/Inspector)
│       ├── Scenes/                  RinkSceneManager, RinkTextureManager,
│       │                            @concurrent renderers (Rink, Heatmap,
│       │                            Movement)
│       ├── States/                  ErrorRouter, GroupSelection,
│       │                            RinkCameraState, RinkOverlayState
│       └── Views/                   RinkView, RealityRinkView,
│                                    PlayersListView, GroupListView,
│                                    SensorListView
├── Neutral Zone TrapTests/          Swift Testing – unit + integration
│   ├── Mocks/                       protokol-driven mocky (MockUDPReceiver)
│   ├── Helpers/                     TestHelpers, Tags
│   ├── Application/Services/        Recorder, Playback, Statistics,
│   │                                SensorStreamProcessor, SessionFileManager
│   ├── Domain/                      Models, Services, Errors
│   ├── Infrastructure/              Networking, Files
│   ├── Presentation/                Extensions, States
│   └── Integration/                 E2E pipeline UDP → record → file → playback
├── Neutral Zone TrapUITests/        UI smoke testy (XCTest)
└── Neutral Zone Trap.xcodeproj
```

## Formát souboru `.nzt`

Uložené záznamy jsou JSON dokumenty s UTI `com.sdrda.nzt-session` a příponou
`.nzt`. Obsahují pole `sensorTracks` (seznam záznamů pro jednotlivé senzory)
a datum exportu:

```json
{
  "exportDate": "2026-04-18T20:00:00Z",
  "sensorTracks": [
    {
      "sensorHardwareID": 1,
      "totalDistance": 37.41,
      "positions": [
        { "id": 1, "x": 0.0, "y": 0.0, "timestamp": "…" }
      ]
    }
  ]
}
```

Serializace probíhá přes `NZTDocument` (`FileDocument`) s interním
`NZTWireFormat` (Codable wrapper drží `sensorTracks` + `exportDate`).

## Licence

Projekt vznikl jako bakalářská práce na ČVUT FEL; zdrojové kódy jsou
zveřejněny pro účely obhajoby. Pro jiné použití kontaktujte autora.

## Autor

Šimon Drda — [simondrda64@gmail.com](mailto:simondrda64@gmail.com)
