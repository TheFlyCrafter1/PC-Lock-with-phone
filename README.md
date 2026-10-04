README_DE
PC per Handy sperren
Dieses Paket sperrt deinen Windows-PC von ueberall per Telegram-Knopf.
Der PC baut selbst die Verbindung zu Telegram auf. Du musst keinen Router-Port
oeffnen.
Der Knopf fuehrt lokal den Windows-Aufruf LockWorkStation aus. Das ist
praktisch dasselbe Ergebnis wie Win + L.
Dateien
Setup-PcLockPhone.ps1 koppelt deinen Telegram-Chat.
Start-PcLockBot.ps1 startet den Listener.
Start-HiddenNow.ps1 startet den Listener sofort versteckt im Hintergrund.
Status-PcLockBot.ps1 zeigt Config, Autostart und laufende Prozesse.
Install-Autostart.ps1 startet den Listener automatisch bei Windows-Login.
Uninstall-Autostart.ps1 entfernt den Autostart wieder.
Lock-ThisPcNow.ps1 testet nur lokal die Windows-Sperre.
pc-lock.log entsteht automatisch als Logdatei.
Einrichtung
Oeffne Telegram auf deinem Handy.
Schreibe an @BotFather: /newbot
Gib dem Bot einen Namen und kopiere den Bot-Token.
Oeffne PowerShell auf dem PC.
Fuehre aus:
cd "C:\Users\patri\Documents\Codex\2026-08-11\erstellen\outputs\pc-lock-phone"
powershell -ExecutionPolicy Bypass -File .\Setup-PcLockPhone.ps1
​
Fuege den Bot-Token ein.
Schreibe innerhalb von 3 Minuten in Telegram an deinen neuen Bot: /pair
Danach bekommst du den Knopf PC sperren.
Test starten
cd "C:\Users\patri\Documents\Codex\2026-08-11\erstellen\outputs\pc-lock-phone"
powershell -ExecutionPolicy Bypass -File .\Start-PcLockBot.ps1
​
Solange dieses Fenster laeuft, kannst du am Handy im Telegram-Chat auf
PC sperren tippen.
Wenn du das Fenster schliesst, stoppt dieser Test-Listener. Zum versteckten
Starten ohne offenes Fenster:
cd "C:\Users\patri\Documents\Codex\2026-08-11\erstellen\outputs\pc-lock-phone"
powershell -ExecutionPolicy Bypass -File .\Start-HiddenNow.ps1
​
Wichtig: Diesen Befehl musst du in deiner eigenen Windows-PowerShell ausfuehren.
Der Bot-Token ist Windows-verschluesselt und kann aus anderen Benutzerkontexten
nicht gelesen werden.
Status pruefen:
powershell -ExecutionPolicy Bypass -File .\Status-PcLockBot.ps1
​
Autostart einschalten
Wenn der Test klappt:
cd "C:\Users\patri\Documents\Codex\2026-08-11\erstellen\outputs\pc-lock-phone"
powershell -ExecutionPolicy Bypass -File .\Install-Autostart.ps1
​
Ab dem naechsten Windows-Login laeuft der Listener automatisch. Der Installer
startet ihn auch direkt einmal. Er nutzt zuerst eine geplante Windows-Aufgabe.
Falls Windows das blockiert, legt er automatisch einen versteckten Starter in
deinen Startup-Ordner.
Autostart entfernen
cd "C:\Users\patri\Documents\Codex\2026-08-11\erstellen\outputs\pc-lock-phone"
powershell -ExecutionPolicy Bypass -File .\Uninstall-Autostart.ps1
​
Wichtig
Der PC muss an sein, Internet haben und in deinem Windows-Benutzer laufen.
Das entsperrt den PC nicht, es sperrt ihn nur.
Der Bot-Token ist geheim. Wenn ihn jemand bekommt, erstelle bei @BotFather
mit /revoke einen neuen Token und fuehre das Setup nochmal aus.
config.json enthaelt den Token Windows-verschluesselt fuer deinen Benutzer.
Auf einem anderen Windows-Benutzer oder PC ist er nicht nutzbar.
