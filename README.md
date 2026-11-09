# mac-pc-bridge

Ett tangentbord, en mus och två datorer: en Windows-PC och en Mac på samma skrivbord.

Jag sitter vid min Windows-dator men använder MacBooken bredvid hela tiden. Jag ville kunna dra musen rakt över till Macen, skriva på den med PC-tangentbordet och skicka filer mellan datorerna. Det skulle fungera utan att Macen fylldes av program som är igång i onödan när jag är borta.

Det här repot är min lösning. Allt som går att installera på Mac-sidan installeras med ett kommando.

## Vad det gör

| Del | Vad | Hur |
|---|---|---|
| **Deskflow** | PC:ns mus och tangentbord styr Macen. Kopierad text följer med. | Färdigt open source-program. PC = server, Mac = klient |
| **LocalSend** | Skicka filer mellan datorerna, som AirDrop. | Färdigt open source-program |
| **keyremap** | Windows-kortkommandon fungerar på Macen: vänster Alt+Space öppnar Spotlight, Alt+Tab byter program, Alt+C tar en skärmdump av ett område och Ctrl+A/C/V markerar allt/kopierar/klistrar in. | Eget litet Swift-program |
| **home-autostart** | Deskflow och LocalSend startar av sig själva när Macen kommer hem och stängs på andra nätverk. | Eget bash-skript + macOS LaunchAgent |

## Beslut och varför

- **Deskflow i stället för fjärrskrivbord.** Båda skärmarna står framför mig, så jag behöver inte se Macens skärm på PC:n. Jag behöver bara styra den. Deskflow ger lägre fördröjning och skarp bild, eftersom inget videoflöde skickas.
- **Alt-kortkommandona bara från PC-tangentbordet.** keyremap kontrollerar vilket program tangenttrycket kommer från. Bara tryck som kommer via Deskflow görs om, så MacBookens eget tangentbord fungerar som vanligt.
- **Alt+Tab håller växlaren öppen.** Macens programväxlare är öppen så länge Cmd hålls nere. keyremap trycker därför ner Cmd vid första Tab och släpper den när Alt släpps.
- **Ctrl+C lämnas ifred i terminalen.** Där betyder Ctrl+C "avbryt", så terminalprogram är undantagna.
- **Hemnätverket känns igen på routern, inte på wifi-namnet.** På nyare macOS krävs platsbehörighet för att läsa wifi-namnet. Routerns MAC-adress går att läsa utan behörighet och är dessutom unik, medan två nätverk kan heta samma sak.
- **Reagerar bara när nätverket byts.** Om jag stänger LocalSend hemma startar den inte om fem minuter senare. Om nätverket försvinner helt en kort stund händer ingenting.
- **Stängs försiktigt först.** Apparna ombeds först att avsluta på vanligt sätt och tvingas bara om de vägrar. LocalSend vägrar, och Deskflow lämnar en hjälpprocess kvar.

## Installera

### Mac
Kräver [Homebrew](https://brew.sh) och Apples utvecklarverktyg (`xcode-select --install`).

```bash
git clone https://github.com/matte0fc/mac-pc-bridge.git
cd mac-pc-bridge
./install.sh
```

Kör installationen medan Macen är ansluten till hemnätverket. Skriptet frågar om det nätverk du är på är ditt hemnätverk. Sedan ber macOS om tillgänglighetsbehörighet (Accessibility) för `keyremap`, som behövs för att kunna läsa tangenttryck.

Inställningarna hamnar i `~/Library/Application Support/mac-pc-bridge/home.conf` och loggarna i `~/Library/Logs/mac-pc-bridge/`. Allt tas bort med `./uninstall.sh`.

### Windows
PC:n flyttar inte på sig, så där räcker det att programmen startar vid inloggning:

```powershell
winget install Deskflow.Deskflow
winget install LocalSend.LocalSend
```

Starta Deskflow som **Server** och lägg Macen till höger eller vänster om PC:n i skärmlayouten. Slå på start vid inloggning i både Deskflow och LocalSend. I LocalSend kan du slå på **Quick Save**, så tas filer från Macen emot utan att du behöver klicka på Acceptera.

## Felsökning

- **Alt+Space gör ingenting:** titta i `~/Library/Logs/mac-pc-bridge/keyremap.log`. Saknas behörigheten, ge den och kör `launchctl kickstart -k gui/$(id -u)/local.mac-pc-bridge.keyremap`.
- **Apparna startar inte hemma:** titta i `home-autostart.log`. Har du bytt router, kör `./install.sh` igen hemifrån.
- **Text följer inte med:** Deskflow skickar urklippet när muspekaren byter skärm. Kopiera, flytta pekaren och klistra in.

## Hur det byggdes

Jag är inte utvecklare. Det här byggde jag tillsammans med [Claude Code](https://claude.com/claude-code), Anthropics AI-verktyg för programmering. Min del var att se problemet, ställa kraven, välja mellan lösningarna och testa allt på mina egna datorer tills det fungerade som jag ville. Claude skrev koden.

## Licens

MIT
