# IlumnulOS - Windows 11 Ultimate Optimizer

![Version](https://img.shields.io/badge/version-2.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%2011-blue.svg)
![Language](https://img.shields.io/badge/language-PowerShell%205.1+-brightgreen.svg)
![License](https://img.shields.io/badge/license-MIT-orange.svg)

IlumnulOS este un tool CLI (PowerShell) pentru Windows 11 care rulează o suită completă de optimizări: performanță/latency, privacy, debloat și eliminarea componentelor AI (Copilot/Recall etc.). Interfața este un dashboard în consolă, iar log-ul se salvează automat pe Desktop.

---

## Cuprins
- [Ce face](#ce-face)
- [Cerințe](#cerințe)
- [Instalare](#instalare)
- [Utilizare](#utilizare)
- [Module](#module)
- [Siguranță](#siguranță)
- [Troubleshooting](#troubleshooting)
- [Disclaimer](#disclaimer)
- [License](#license)

---

## Ce face
- Optimizează setări de sistem pentru responsiveness și gaming/latency (MMCSS, power plan, GPU/CPU priorities).
- Debloat: dezinstalează aplicații inutile și reduce servicii/background tasks.
- Privacy: limitează telemetria și setări de tracking.
- RemoveAI: dezactivează/elimină componente AI din Windows unde este posibil.
- Cleanup: curăță temporare, cache-uri și face restart la Explorer la final.
- Creează un log pe Desktop: `IlumnulOS_Log.txt`.

Note:
- `Win32PrioritySeparation` este setat la `0x00000028 (40)` (nu `0x1c`).
- Tool-ul creează automat PSDrive `HKU:` când are nevoie (pentru `HKEY_USERS`).

---

## Cerințe
- OS: Windows 11 (recomandat). Poate funcționa și pe Windows 10, dar nu este țintit.
- PowerShell: 5.1+.
- Drepturi: Administrator (UAC).
- Consolă: recomandat minim 120x30 pentru layout stabil.

---

## Instalare

### Opțiunea 1: Run direct (recomandat)
Rulează în PowerShell (Administrator):

```powershell
irm https://raw.githubusercontent.com/xhowlzzz/IlumnulOS/main/IlumnulOS.ps1 | iex
```

### Opțiunea 2: Manual
```powershell
git clone https://github.com/xhowlzzz/IlumnulOS.git
cd IlumnulOS
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\IlumnulOS.ps1
```

Dacă ai descărcat ZIP:
- Click dreapta pe ZIP -> Properties -> Unblock -> Apply.

---

## Utilizare
1. Deschide PowerShell ca Administrator.
2. Rulează `.\IlumnulOS.ps1`.
3. Navighează în meniu cu Up/Down și Enter:
   - Start Optimization (Full Suite)
   - Exit

---

## Module
- `Modules\Optimize.psm1` – optimizări de sistem (responsiveness, registry tweaks, storage tweaks).
- `Modules\Gaming.psm1` – setări pentru gaming/latency (power, MMCSS, network, GPU/CPU).
- `Modules\Debloat.psm1` – debloat și privacy hardening (aplicații, servicii, policy tweaks).
- `Modules\RemoveAI.psm1` – eliminare/disable AI features (Copilot/Recall, task-uri, setări).

Rularea “Full Suite” execută aceste module în secțiuni `[1/6]` … `[6/6]`, afișate în Status și Log.

---

## Siguranță
- Rulează pe propria răspundere: modifică registry, servicii și policy settings.
- Recomandat: backup + restore point (scriptul încearcă să creeze un restore point).
- Nu loghează chei sau date sensibile.
- Nu dezactivează intenționat VBS/Core Isolation din UI; schimbările sunt orientate pe performanță, dar urmăresc compatibilitate.

---

## Troubleshooting
**Scriptul se închide imediat**
- Rulează dintr-un PowerShell (Admin) ca să vezi erorile:
  - `.\IlumnulOS.ps1`
- Setează policy doar pentru sesiunea curentă:
  - `Set-ExecutionPolicy Bypass -Scope Process -Force`

**UI se “rupe” / text peste chenar**
- Mărește fereastra (recomandat 120x30 sau mai mare).

**Erori cu HKU: / HKEY_USERS**
- Scriptul creează automat PSDrive `HKU:`; dacă ai restricții de policy, rulează strict ca Administrator.

---

## Disclaimer
Folosește pe propria răspundere. Orice tool de optimizare poate cauza instabilitate în anumite configurații. Fă backup înainte și păstrează posibilitatea de rollback (restore point).

---

## License
MIT. Vezi [LICENSE](LICENSE).
