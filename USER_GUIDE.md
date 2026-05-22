# Uživatelská příručka — Neutral Zone Trap

Tento dokument popisuje, jak používat aplikaci **Neutral Zone Trap** pro
zobrazení, záznam a analýzu polohových dat hokejového hráče.

Pro informace o architektuře a instalaci viz [`README.md`](README.md).

## Obsah

1. [První spuštění](#první-spuštění)
2. [Rozložení aplikace](#rozložení-aplikace)
3. [Správa hráčů, senzorů a skupin](#správa-hráčů-senzorů-a-skupin)
4. [Živé sledování na hřišti](#živé-sledování-na-hřišti)
5. [Záznam a export](#záznam-a-export)
6. [Přehrávání a analýza uloženého záznamu](#přehrávání-a-analýza-uloženého-záznamu)
7. [Klávesové zkratky](#klávesové-zkratky)
8. [Řešení potíží](#řešení-potíží)

## První spuštění

1. Spusťte aplikaci **Neutral Zone Trap**.
2. Aplikace otevře hlavní okno se čtyřmi záložkami v postranním panelu:
   **Rink**, **Players**, **Groups** a **Sensors**.
3. Po otevření záložky **Rink** aplikace začne naslouchat na UDP portu
   **12345** a čeká na pakety z hardwarové jednotky (nebo simulátoru).
   Hodnota portu je definovaná v `AppConfig.udpPort`.

Před prvním smysluplným použitím je vhodné:

1. Přidat alespoň jednoho hráče (záložka **Players**).
2. Přidat alespoň jeden senzor se správným hardware ID (záložka **Sensors**), která máte v plánu posílat.
3. (Volitelné) Sdružit hráče do skupiny (záložka **Groups**).
4. Přiřadit senzor k hráči — senzor bez přiřazeného hráče se na hřišti
   nezobrazí s číslem.

## Rozložení aplikace

### Záložka Rink

Hlavní pohled na ledovou plochu 60 × 30 m (norma IIHF). Upravovat velikost
hřiště půjde v budoucí verzi.

- Ve **2D režimu** se hráči zobrazují jako barevné body s číslem dresu.
- **3D režim** zapnete tlačítkem *Switch to 3D view* v panelu nástrojů.
  V 3D lze scénou otáčet držením pravého tlačítka myši (orbital camera).
- **Inspector** (pravá strana) otevřete tlačítkem *Player Details* —
  zobrazuje seznam hráčů, aktivních skupin a jejich statistik (vzdálenost,
  aktuální rychlost).

### Záložka Players

Správa hokejových hráčů: jméno, číslo dresu a jejich senzorů. Seznam je řazen podle čísla
dresu.

### Záložka Groups

Správa skupin (např. „Obrana", „Útok", „Brankáři"). Skupinu tvoří jméno,
barva a seznam hráčů.

### Záložka Sensors

Správa senzorů. Každý senzor má:

- **hardware ID** (nezáporné celé číslo, `UInt64`) — hodnota, která
  přichází v UDP paketu jako 8bajtové little-endian celé číslo a interně
  se reprezentuje typem `SensorHardwareID`,

## Správa hráčů, senzorů a skupin

### Přidání hráče

1. Přejděte na záložku **Players**.
2. Klikněte na tlačítko **+** v pravém horním rohu.
3. Vyplňte jméno a číslo dresu. Případně přidejte i senzory
4. Potvrďte tlačítkem **Save**.

### Přidání senzoru

1. Přejděte na záložku **Sensors**.
2. Klikněte na **+**.
3. Vyplňte **hardware ID** (musí odpovídat hodnotě v UDP paketech / simuluje unikátní označení hardwarového senzoru).
5. Uložte.

### Vytvoření skupiny

1. Přejděte na záložku **Groups**.
2. Klikněte na **+**, vyplňte jméno a vyberte barvu.
3. V detailu skupiny přidejte hráče.

### Úprava a mazání

Všechny entity lze upravit kliknutím na jejich řádek v seznamu; smazat je
lze swipnutím nebo zapnutím editovacího režimu (pouze iPhone/iPad funkcionalita).

## Živé sledování na hřišti

1. Přejděte na záložku **Rink** — automaticky začínáme v režimu *live*.
2. Z hardwarové jednotky (nebo simulátoru) začněte posílat pakety na
   `127.0.0.1:12345` ve formátu popsaném v `README.md`.
3. Pozice hráčů se aktualizují v reálném čase. Obrysem a jménem je
   označen pouze senzor přiřazený k existujícímu hráči.

Zobrazení lze ovládat v horní liště:

- **Switch to 3D view / 2D view** přepíná mezi 2D a 3D pohledem.
- **Active Groups** filtruje, kteří hráči (resp. skupiny) mají být na ledě
  viditelní.
- **Statistics** otevře boční panel se statistikami.

## Záznam a export

1. V režimu *live* stiskněte červené tlačítko **Record** v horní liště
   (vpravo). Nahrávání je indikováno změnou ikony na *Stop* a změnou informačního textu
   nad hřištěm.
2. Během záznamu se všechny příchozí pozice ukládají do operační paměti.
3. Stisknutím **Stop** záznam ukončíte; aplikace automaticky přepne do
   režimu *playback*, kde si záznam můžete prohlédnout.
4. Pro uložení na disk použijte v liště tlačítko **Export** (nebo
   zkratku `⌘S`). Soubor se ukládá s příponou `.nzt` a je čitelný
   aplikací pro pozdější analýzu.

Pokud se pokusíte opustit relaci bez exportu, aplikace se zeptá, zda
opravdu chcete záznam zahodit.

## Přehrávání a analýza uloženého záznamu

1. V režimu *live* klikněte na **Import** (nebo `⌘I`) a vyberte `.nzt`
   soubor. Alternativně lze soubor `.nzt` **přetáhnout z Finderu** přímo
   do pohledu na hřiště — plocha se při najetí zvýrazní a po uvolnění
   se záznam automaticky načte.
2. Aplikace přepne do režimu *playback*. V dolní části hřiště se objeví
   ovládací panel:
   - tlačítko **Play / Pause**,
   - časová osa pro skokovou navigaci,
   - aktuální čas.
3. V Inspectoru vpravo jsou zobrazeny pohybové statistiky:
   - **ujetá vzdálenost** (metry),
   - **aktuální rychlost** (m/s).
4. Pohled lze přepnout do **3D režimu** stejně jako při živém sledování.
5. Přehrávání lze opustit tlačítkem **Exit** v horní liště (ikona koše).
   Pokud importovaný / nahraný záznam není uložen, aplikace vyžádá potvrzení.

### Trajektorie a heatmapa

Pro vygenerování trajektorie nebo heatmapy se aplikace
musí nacházet v režimu *nahrávání* nebo *přehrávání* a vyvolá se stisknutím tlačítka
u daného hráče v bočním panelu.

## Klávesové zkratky

| Zkratka | Akce                             |
|---------|----------------------------------|
| `⌘1`    | Přejít na záložku **Rink**        |
| `⌘2`    | Přejít na záložku **Players**     |
| `⌘3`    | Přejít na záložku **Groups**      |
| `⌘4`    | Přejít na záložku **Sensors**     |
| `⌘S`    | Exportovat aktuální relaci        |
| `⌘I`    | Importovat `.nzt` soubor          |

## Řešení potíží

**Na hřišti se nic neděje, i když simulátor posílá data.**

- Zkontrolujte, že simulátor posílá pakety na `127.0.0.1:12345`.

**Export / import skončil chybou.**

- Pokud importujete soubor z jiného zdroje než Finderu (například
  získaný přes AirDrop či shared album), zkopírujte jej nejdřív lokálně.

**Aplikace není vidět jako naslouchající UDP klient.**
- Ponechte aplikaci otevřenou na záložce **Rink**
  a spusťte simulátor z terminálu.

---

Pro hlášení chyb nebo dotazy kontaktujte autora — viz `README.md`.
