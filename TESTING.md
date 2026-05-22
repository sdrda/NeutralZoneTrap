# Manuální testování — Neutral Zone Trap

Tento dokument obsahuje scénáře pro **manuální testování** aplikace. Doplňuje
automatizované unit, integrační a UI testy.

Scénáře vycházejí z **případů užití (UC-01 až UC-28)** definovaných v kapitole
analýzy bakalářské práce a z **funkčních / nefunkčních požadavků** (FRQ-1 až FRQ-13,
NFR-1 až NFR-7). Pokrývají hlavní toky i alternativní a chybové větve. Sada je
dále doplněna o **zbytkové scénáře** (kombinace funkcí, platformní chování)
a o **negativní scénáře** (např. pokus o nahrávání, aniž by přišla jakákoliv
pozice).

## Obsah

1. [Testovací prostředí](#testovací-prostředí)
2. [Spuštění simulátoru telemetrie](#spuštění-simulátoru-telemetrie)
3. [Konvence a protokol](#konvence-a-protokol)
4. [Pozitivní scénáře z případů užití](#pozitivní-scénáře-z-případů-užití)
   - [Živé sledování (UC-01–04)](#a-živé-sledování-uc-0104)
   - [Práce s entitami (UC-05–18)](#b-práce-s-entitami-uc-0518)
   - [Nahrávání a práce se záznamem (UC-19–28)](#c-nahrávání-a-práce-se-záznamem-uc-1928)
5. [Zbytkové (doplňkové) scénáře](#zbytkové-doplňkové-scénáře)
6. [Negativní scénáře](#negativní-scénáře)
7. [Matice pokrytí](#matice-pokrytí)

---

## Testovací prostředí

Ověření probíhá na zařízeních uvedených v práci:

| Zařízení | OS | Role |
|---|---|---|
| iPad Pro (4. generace) | iPadOS | primární cílová platforma (NFR-1) |
| iPhone 17 Pro Max | iOS | sekundární, ověření kompaktního layoutu |
| MacBook Pro M3 Pro | macOS | desktop, klávesové zkratky, drag-and-drop z Finderu |

Pro scénáře CloudKit synchronizace jsou potřeba **dvě zařízení přihlášená
do téhož iCloud účtu**.

## Spuštění simulátoru telemetrie

Většina scénářů vyžaduje zdroj polohových dat. Aplikace ve výchozím stavu
naslouchá na UDP portu **12345** (`AppConfig.udpPort`). Minimální simulátor
(viz `README.md`) posílá pakety o pevné velikosti 32 B (`<ddQd` =
x, y, sensorID, timestamp):

```python
import socket, struct, time, math
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
t = 0.0
while True:
    x = 20 * math.sin(t)
    y = 10 * math.cos(t)
    packet = struct.pack("<ddQd", x, y, 5, time.time())  # sensorID 5
    sock.sendto(packet, ("127.0.0.1", 12345))
    t += 0.05
    time.sleep(0.05)
```

Pro scénáře s více hráči posílejte pakety s několika různými `sensorID`.
Negativní scénáře vyžadují varianty (vadný paket, žádný paket, jiný port) —
jsou popsány u jednotlivých testů.

## Konvence a protokol

- **ID scénáře:** `MT-xx` (pozitivní), `MT-Nxx` (negativní).
- **Pokrývá:** odkaz na UC / FRQ / NFR, případně na alternativní tok UC.
- Každý scénář má **předpoklady → kroky → očekávaný výsledek**.

## Pozitivní scénáře z případů užití

### A. Živé sledování (UC-01–04)

#### MT-01 — Zobrazení živých pozic na hřišti
**Pokrývá:** UC-01, UC-02 · FRQ-1, FRQ-2 · NFR-3
**Předpoklady:** v databázi existuje senzor s hardware ID 5 přiřazený hráči;
aplikace je na záložce **Rink** v režimu *live*.
**Kroky:**
1. Spusťte simulátor posílající pakety pro sensorID 5 na `127.0.0.1:12345`.
2. Sledujte model hřiště.
3. Postupně přidejte další sensorID (např. 6, 7) do simulátoru.
**Očekávaný výsledek:** bod hráče se objeví a plynule se pohybuje podle dat;
hráč přiřazený k senzoru má obrys, číslo dresu a jméno. Aktualizace probíhá
bez viditelného zpoždění (řádově do 100 ms) i pro 30+ souběžných hráčů.

#### MT-02 — Okamžitá rychlost hráče
**Pokrývá:** UC-04 · FRQ-3
**Předpoklady:** běží MT-01; otevřený **Inspector** (tlačítko *Statistics*).
**Kroky:**
1. Sledujte hodnotu okamžité rychlosti u aktivního hráče.
2. Změňte v simulátoru rychlost pohybu (větší počet souřadnic za stejný čas).
**Očekávaný výsledek:** zobrazená rychlost (m/s) reaguje na změnu pohybu,
roste/klesá konzistentně s rychlostí pohybu bodu.

#### MT-03 — Výběr aktivních skupin a vizuální odlišení
**Pokrývá:** UC-03 · FRQ-13
**Předpoklady:** existují alespoň dvě skupiny s odlišnou barvou a přiřazenými
hráči; běží živé pozice pro hráče z obou skupin.
**Kroky:**
1. V horní liště otevřete menu **Active Groups**.
2. Aktivujte jednu skupinu.
3. Aktivujte/deaktivujte druhou skupinu.
**Očekávaný výsledek:** hráči aktivní skupiny jsou na ledě barevně odlišeni
od ostatních; změna výběru se projeví okamžitě, deaktivace vrátí výchozí
vzhled.

#### MT-04 — Přepnutí mezi 2D a 3D zobrazením
**Pokrývá:** UC-01 (prezentace), NFR-4
**Předpoklady:** běží živé pozice.
**Kroky:**
1. Tlačítkem *Switch to 3D view* přepněte na 3D model.
2. Otáčejte scénou (orbital kamera).
3. Přepněte zpět na 2D.
**Očekávaný výsledek:** pozice hráčů zůstávají konzistentní v obou režimech,
orientace hřiště se zachová, přechod je bez artefaktů.

### B. Práce s entitami (UC-05–18)

#### MT-05 — CRUD nad senzorem
**Pokrývá:** UC-05, UC-06, UC-07, UC-08 · FRQ-10
**Předpoklady:** záložka **Sensors**.
**Kroky:**
1. **+** → zadejte platné hardware ID → **Save** (UC-06).
2. Tapněte na řádek senzoru → změňte hardware ID → **Save** (UC-07).
3. Smažte senzor přes swipnutím / tlačítko v editaci (UC-08).
**Očekávaný výsledek:** senzor se přidá, úprava se projeví v seznamu, smazání
ho odebere. Po smazání senzoru přiřazeného hráči zůstane hráč zachován.

#### MT-06 — CRUD nad hráčem a přiřazení senzoru
**Pokrývá:** UC-09–UC-13 · FRQ-11
**Předpoklady:** existuje alespoň jeden nepřiřazený senzor.
**Kroky:**
1. Záložka **Players** → **+** → jméno, číslo dresu, vyberte senzor → **Save**.
2. Upravte hráče: přidejte/odeberte senzor, změňte číslo → **Save**.
3. Ověřte v záložce **Sensors**, že přiřazení odpovídá.
**Očekávaný výsledek:** hráč se uloží s vybranými senzory; reassignment senzorů
je konzistentní napříč oběma seznamy; seznam hráčů je řazen podle čísla dresu.

#### MT-07 — CRUD nad skupinou a přiřazení hráčů
**Pokrývá:** UC-14–UC-18 · FRQ-12
**Předpoklady:** existuje několik hráčů.
**Kroky:**
1. Záložka **Groups** → **+** → jméno, barva → **Save**.
2. V detailu skupiny přidejte hráče.
3. Upravte skupinu (barva, členové), poté ji smažte.
**Očekávaný výsledek:** skupina se vytvoří, hráči se přiřadí, úpravy se projeví;
smazání skupiny hráče nesmaže. Barva skupiny se použije pro odlišení na hřišti
(viz MT-03).

### C. Nahrávání a práce se záznamem (UC-19–28)

#### MT-08 — Nahrání živého vysílání
**Pokrývá:** UC-19, UC-20 · FRQ-4
**Předpoklady:** běží živé pozice (MT-01); žádná nahrávka neprobíhá.
**Kroky:**
1. V horní liště stiskněte červené tlačítko **Record**.
2. Nechte nahrávat ~15 s při běžícím simulátoru.
3. Stiskněte **Stop**.
**Očekávaný výsledek:** během nahrávání se ikona změní na *Stop* a informační
text nad hřištěm indikuje běžící záznam. Po **Stop** aplikace přepne do režimu
*playback* nad právě nahranou (dosud neuloženou) relací.

#### MT-09 — Statistiky vzdálenosti
**Pokrývá:** UC-27, UC-28 · FRQ-5
**Předpoklady:** běží nahrávání (MT-08); otevřený Inspector.
**Kroky:**
1. Ukončete nahrávání.
2. V inspectoru jsou vidět ujeté vzdálenosti jednotlivých senzor
**Očekávaný výsledek:** každý hráč má ujetou vzdálenost.

#### MT-10 — Přehrání záznamu a navigace časovou osou
**Pokrývá:** UC-23 · FRQ-6 · NFR-7
**Předpoklady:** v paměti je relace s neprázdnou stopou (po MT-08 nebo MT-12).
**Kroky:**
1. Stiskněte **Play** — pozice se přehrávají v původním tempu (ne v tempu
   doručení paketů).
2. **Pause** → pozice zamrznou; **Play** pokračuje od ukazatele.
3. Přetáhněte ukazatel časové osy na jiný okamžik.
4. Nechte přehrávání dojít na konec.
**Očekávaný výsledek:** přehrávání respektuje reálné časy nahraných pozic;
skok na časové ose okamžitě zobrazí odpovídající pozice a plynule pokračuje
(byl-li předtím stav *playing*); na konci se přehrávání zastaví, při dalším
spuštění začne znovu od začátku.

#### MT-11 — Uložení záznamu do souboru
**Pokrývá:** UC-22 · FRQ-7 · NFR-5
**Předpoklady:** aplikace v režimu *playback* s relací v paměti.
**Kroky:**
1. **Export** v liště (nebo `⌘S`).
2. V systémovém dialogu zvolte název a umístění → potvrďte.
3. Zkuste relaci opustit tlačítkem **Exit**.
**Očekávaný výsledek:** vznikne soubor `.nzt` s daty relace; aplikace si pamatuje,
že relace je uložena, a při opuštění **nezobrazí** potvrzovací dialog.

#### MT-12 — Načtení záznamu ze souboru (systémový dialog)
**Pokrývá:** UC-21 · FRQ-7
**Předpoklady:** existuje validní `.nzt` soubor (z MT-11).
**Kroky:**
1. V režimu *live* stiskněte **Import** (nebo `⌘I`).
2. Vyberte `.nzt` soubor → potvrďte.
**Očekávaný výsledek:** relace se zrekonstruuje, aplikace přejde do *playback*
a relaci eviduje jako uloženou.

#### MT-13 — Načtení záznamu drag-and-drop z Finderu
**Pokrývá:** UC-21 (alternativní vstup) · FRQ-7
**Předpoklady:** macOS/iPadOS; validní `.nzt` soubor ve Finderu/Souborech.
**Kroky:**
1. Přetáhněte `.nzt` soubor nad pohled na hřiště.
**Očekávaný výsledek:** plocha se při najetí zvýrazní; po uvolnění se záznam
automaticky načte a aplikace přejde do *playback*.

#### MT-14 — Vygenerování heatmapy hráče
**Pokrývá:** UC-24, UC-25 · FRQ-9
**Předpoklady:** režim *nahrávání* nebo *playback*; vybraný hráč má nenulový počet
zaznamenaných pozic.
**Kroky:**
1. V bočním panelu u hráče vyvolejte akci pro vygenerování heatmapy.
**Očekávaný výsledek:** nad modelem hřiště se vykreslí teplotní mapa hustoty
výskytu hráče, korektně překrytá nad ledovou plochou.

#### MT-15 — Vygenerování trajektorie hráče
**Pokrývá:** UC-26 · FRQ-8
**Předpoklady:** jako MT-14.
**Kroky:**
1. V bočním panelu u hráče vyvolejte akci pro vykreslení trajektorie.
**Očekávaný výsledek:** trajektorie pohybu se vykreslí na 2D modelu hřiště.

#### MT-16 — Heatmapa skupiny
**Pokrývá:** UC-25 (skupinová varianta) · FRQ-9, FRQ-12
**Předpoklady:** existuje skupina s více hráči, kteří mají v relaci pozice.
**Kroky:**
1. V bočním panelu zvolte generování heatmapy pro celou skupinu.
**Očekávaný výsledek:** vykreslí se společná heatmapa shromažďující pozice
všech členů skupiny napříč jejich senzory.

---

## Zbytkové (doplňkové) scénáře

#### MT-17 — Tmavý / světlý režim
**Pokrývá:** NFR-6
**Kroky:** přepněte systémové barevné schéma (světlé ↔ tmavé) za běhu aplikace
se zobrazenými sheety, toolbarem a překryvnou vrstvou (heatmapa/trajektorie).
**Očekávaný výsledek:** všechny komponenty se přizpůsobí, kontrasty toolbaru,
sheetů i překryvů zůstanou čitelné.

#### MT-18 — Klávesové zkratky (macOS)
**Pokrývá:** NFR-4
**Kroky:** vyzkoušejte `⌘1`–`⌘4` (přepnutí záložek), `⌘S` (export), `⌘I` (import).
**Očekávaný výsledek:** každá zkratka provede odpovídající akci; `⌘S` je
relevantní jen s relací v paměti.

#### MT-19 — CloudKit synchronizace mezi zařízeními
**Pokrývá:** NFR-2
**Předpoklady:** dvě zařízení, stejný iCloud účet, obě s aplikací.
**Kroky:**
1. Na zařízení A přidejte hráče, skupinu a senzor.
2. Po chvíli zkontrolujte zařízení B.
**Očekávaný výsledek:** přidané entity se propagují na zařízení B (hráči,
skupiny, senzory).

#### MT-20 — Adaptivní rozložení (sidebar / kompaktní šířka)
**Pokrývá:** NFR-1, NFR-4
**Kroky:** zužte okno (macOS) / otočte iPhone / rozdělte obrazovku (iPadOS).
**Očekávaný výsledek:** postranní panel se sbalí do přepínače, hlavní obsah
zůstane použitelný; klávesnice na iPhone nepřekrývá editovaná pole ve formulářích.

#### MT-21 — Senzor v paketech bez přiřazeného hráče
**Pokrývá:** UC-01, alternativní tok 3b
**Kroky:** posílejte pakety pro sensorID, které **není** přiřazeno žádnému hráči.
**Očekávaný výsledek:** pozice se na hřišti vykreslí, ale bod je zobrazen bez
jména a čísla dresu. Po pozdějším přiřazení hráče (bez restartu) se doplní jméno.

#### MT-22 — Potvrzení při opuštění neuloženého záznamu
**Pokrývá:** UC-22 (postpodmínka)
**Předpoklady:** nahraná/importovaná relace, která **nebyla** uložena.
**Kroky:** stiskněte **Exit** (ikona koše) v režimu *playback*.
**Očekávaný výsledek:** aplikace vyžádá potvrzení zahození. Po uložení (MT-11)
se dialog už nezobrazí.

---

## Negativní scénáře

#### MT-N1 — Pokus o nahrávání, aniž přijde jakákoliv pozice
**Pokrývá:** UC-19/UC-20 (degenerovaný vstup) · FRQ-4
**Předpoklady:** aplikace na **Rink** v režimu *live*, **simulátor neběží**
(nebo posílá na jiný port — viz MT-N9).
**Kroky:**
1. Stiskněte **Record**.
2. Nechte „nahrávat" ~10 s, aniž by dorazil jediný paket.
3. Stiskněte **Stop**.
**Očekávaný výsledek:** nahrávání lze spustit i zastavit bez pádu; informační
text korektně indikuje běžící i ukončený záznam. Statistiky v Inspectoru zůstávají
nulové. Po **Stop** aplikace přepne do *playback* nad **prázdnou relací** —
přehrávání nelze spustit a zobrazí se chyba (viz MT-N7).

#### MT-N2 — Vadný / příliš krátký paket
**Pokrývá:** UC-01, alternativní tok 3a
**Kroky:** v simulátoru pošlete mix validních (32 B) a vadných paketů (např.
prázdný paket, paket < 32 B, paket s přebytečnými bajty) pro několik senzorů.
**Očekávaný výsledek:** vadné pakety jsou tiše zahozeny, aplikace nespadne,
vykreslení ostatních (validních) hráčů není ovlivněno.

#### MT-N3 — Selhání telemetrického streamu během nahrávání
**Pokrývá:** UC-20, alternativní tok 2a
**Kroky:** během běžícího nahrávání (MT-08) náhle **ukončete simulátor**.
**Očekávaný výsledek:** dosud zachycená data zůstanou v paměti; aplikace
nezamrzne.

#### MT-N4 — Poškozený `.nzt` soubor
**Pokrývá:** UC-21, alternativní tok 4a
**Předpoklady:** soubor s příponou `.nzt`, jehož obsah **není** validní JSON
(např. ručně poškozený nebo prázdný soubor).
**Kroky:** zkuste jej importovat (dialog nebo drag-and-drop).
**Očekávaný výsledek:** aplikace zobrazí chybový alert (dekódovací chyba);
stav aplikace zůstane nezměněn (zůstává v *live*, žádná relace se nenačte).

#### MT-N5 — Soubor nerozpoznaného formátu
**Pokrývá:** UC-21, alternativní tok 2a
**Kroky:**
1. V systémovém dialogu se pokuste vybrat soubor jiného typu (např. `.txt`, `.png`).
2. Přetáhněte soubor jiného typu nad hřiště.
**Očekávaný výsledek:** systémový dialog soubor jiného typu nenabídne k výběru;
drag-and-drop souboru jiného typu je ignorován (plocha se nezvýrazní, nic se nenačte).

#### MT-N6 — Zrušení exportního dialogu
**Pokrývá:** UC-22, alternativní tok 3a
**Kroky:** vyvolejte **Export**, v systémovém dialogu stiskněte **Zrušit**.
**Očekávaný výsledek:** žádný soubor nevznikne; relace zůstane evidována jako
**neuložená** (při opuštění se objeví potvrzovací dialog — viz MT-22).

#### MT-N7 — Přehrávání prázdné relace
**Pokrývá:** UC-23, alternativní tok 2a
**Předpoklady:** v paměti je relace bez pozic (po MT-N1).
**Kroky:** stiskněte **Play**.
**Očekávaný výsledek:** přehrávání nelze zahájit, ukazatel zůstává na začátku,
nedojde k pádu.

#### MT-N8 — Heatmapa hráče bez zaznamenaných pozic
**Pokrývá:** UC-25, alternativní tok 2a
**Předpoklady:** relace, v níž vybraný hráč nemá žádné pozice.
**Kroky:** vyvolejte generování heatmapy pro tohoto hráče.
**Očekávaný výsledek:** akce se nezobrazuje, jelikož ani hráč není vidět v inspectoru.

#### MT-N9 — Simulátor posílá na nesprávný port
**Pokrývá:** příjem dat (UC-02) — negativní konfigurace
**Předpoklady:** aplikace naslouchá na portu 12345 (`AppConfig.udpPort`).
**Kroky:** spusťte simulátor posílající pakety na **jiný port** (např. 12346).
**Očekávaný výsledek:** na hřišti se nezobrazí žádná pozice; aplikace zůstává
stabilní a reaguje. Po přesměrování simulátoru na správný port se pozice začnou
zobrazovat (bez restartu aplikace).

#### MT-N10 — Selhání zápisu při exportu
**Pokrývá:** UC-22, alternativní tok 4a
**Kroky:** pokuste se exportovat do umístění bez oprávnění k zápisu / s
nedostatkem místa (lze simulovat read-only adresářem).
**Očekávaný výsledek:** aplikace zobrazí chybové hlášení, soubor není vytvořen,
relace zůstává neuložená.

#### MT-N11 — Validace formulářů
**Pokrývá:** UC-06/UC-07 (senzor), UC-10/UC-11 (hráč)
**Kroky:**
1. **Sensors → +**: zadejte do hardware ID prázdný text, nečíselné znaky
   (`abc`), záporné/desetinné číslo (`-1`, `1.5`) a hodnotu nad rozsah.
2. **Players → +**: ponechte jméno prázdné nebo jen mezery.
**Očekávaný výsledek:** u nevalidního vstupu je tlačítko **Save** neaktivní
(příp. zobrazena nápověda k povolenému rozsahu); validní hodnota uložení povolí.

---

## Matice pokrytí

Pro kontrolu, že manuální scénáře pokrývají všechny případy užití a hlavní
požadavky:

| UC / požadavek | Pozitivní | Alternativní / negativní |
|---|---|---|
| UC-01 / FRQ-2 | MT-01, MT-04 | MT-21 (3b), MT-N2 (3a) |
| UC-02 / FRQ-1 | MT-01 | MT-N9 |
| UC-03 / FRQ-13 | MT-03 | — |
| UC-04 / FRQ-3 | MT-02 | — |
| UC-05–08 / FRQ-10 | MT-05 | MT-N11 |
| UC-09–13 / FRQ-11 | MT-06 | MT-N11 |
| UC-14–18 / FRQ-12 | MT-07 | — |
| UC-19/UC-20 / FRQ-4 | MT-08 | MT-N1, MT-N3 (2a) |
| UC-27/ FRQ-5 | MT-09 | — |
| UC-23 / FRQ-6, NFR-7 | MT-10 | MT-N7 (2a) |
| UC-22 / FRQ-7 | MT-11 | MT-N6 (3a), MT-N10 (4a), MT-22 |
| UC-21 / FRQ-7 | MT-12, MT-13 | MT-N4 (4a), MT-N5 (2a) |
| UC-25 / FRQ-9 | MT-14, MT-16 | MT-N8 (2a) |
| UC-26 / FRQ-8 | MT-15 | — |
| NFR-1, NFR-4 | MT-04, MT-20 | — |
| NFR-2 | MT-19 | — |
| NFR-6 | MT-17 | — |
