# IlumnulOS - Windows 11 Ultimate Optimizer

![Version](https://img.shields.io/badge/version-2.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%2011-blue.svg)
![Language](https://img.shields.io/badge/language-PowerShell%20%7C%20WPF-brightgreen.svg)
![License](https://img.shields.io/badge/license-MIT-orange.svg)

**IlumnulOS** is a powerful, modern, and comprehensive optimization tool designed specifically for Windows 11. Built with PowerShell and a sleek WPF (Glass/iOS-like) user interface, it provides a one-stop solution to debloat, optimize performance, enhance privacy, and remove invasive AI features like Copilot and Recall.

---

## ðŸ“‹ Table of Contents

- [Features](#-features)
- [Screenshots](#-screenshots)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Usage](#-usage)
- [Modules Overview](#-modules-overview)
- [Troubleshooting](#-troubleshooting)
- [Disclaimer](#-disclaimer)
- [Contributing](#-contributing)
- [License](#-license)

---

## âœ¨ Features

IlumnulOS organizes its capabilities into intuitive modules accessible via a modern sidebar interface:

*   **ðŸ–¥ï¸ Professional Dashboard**: View real-time hardware specifications (CPU, GPU, RAM, Disk) and system uptime in a clean, card-based layout.
*   **ðŸš€ Debloat**: Remove pre-installed bloatware, Windows Store apps, OneDrive, and Cortana to free up resources.
*   **ðŸŽ® Gaming Mode**: Optimize system latency, enable Game Mode, adjust GPU priorities, and disable background services for maximum FPS.
*   **ðŸ”’ Privacy Shield**: Disable telemetry, data collection, location tracking, and advertising IDs to reclaim your privacy.
*   **ðŸ¤– AI Control Center**: **Exclusive Feature**. Completely disable and remove Windows Intelligence, Copilot, Recall (Snapshots), and Office AI integrations.
*   **âš¡ System Tuning**: Apply power plan optimizations, visual effect tweaks, and file system improvements.
*   **ðŸ’» Built-in Terminal**: View real-time logs of all operations directly within the app interface.

---

## ðŸ“¸ Screenshots

*(Add screenshots of the Dashboard, AI Control, and Terminal tabs here)*

---

## âš™ï¸ Prerequisites

Before running IlumnulOS, ensure your system meets the following requirements:

*   **OS**: Windows 10 (2004+) or Windows 11 (Recommended).
*   **PowerShell**: Version 5.1 or newer.
*   **Permissions**: Administrator privileges are required to modify registry keys and services.

---

## ðŸ“¥ Installation

### Option 1: Automatic (Recommended)
Copy and paste the following command into **PowerShell (Administrator)** to download and run IlumnulOS automatically:

```powershell
irm https://raw.githubusercontent.com/xhowlzzz/IlumnulOS/main/IlumnulOS.ps1 | iex
```

### Option 2: Manual
1.  **Download the Repository**:
    You can download the latest release as a ZIP file or clone the repository using Git:
    ```powershell
    git clone https://github.com/xhowlzzz/IlumnulOS.git
    ```

2.  **Unblock Files** (If downloaded as ZIP):
    Right-click the ZIP file -> Properties -> Check "Unblock" -> Apply.

3.  **Set Execution Policy**:
    PowerShell scripts may be blocked by default. Open PowerShell as Administrator and run:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    ```

---

## ðŸš€ Usage

1.  Navigate to the `IlumnulOS` directory.
2.  Right-click on `IlumnulOS.ps1` and select **Run with PowerShell**.
3.  **Grant Administrator Access** when prompted by UAC.
4.  The GUI will launch. Use the sidebar to navigate between modules.
5.  **One-Click Optimization**: For a quick boost, click the "ONE-CLICK OPTIMIZE" button on the Dashboard.
6.  **Manual Tuning**: Navigate to specific tabs (Debloat, Gaming, AI) to toggle individual settings.

> **Note**: All actions are logged in the **Terminal** tab. The app will automatically switch to this view when you initiate an operation.

---

## ðŸ“¦ Modules Overview

### 1. RemoveAI (`Modules\RemoveAI.psm1`)
A cutting-edge module to strip AI components:
*   Disables **Windows Copilot** & Bing Chat.
*   Removes **Recall** (Snapshot) features and scheduled tasks.
*   Cleans AI-related Appx packages and registry keys.
*   Blocks AI data harvesting in Edge and Office.

### 2. Debloat (`Modules\Debloat.psm1`)
*   Removes "sponsored" apps (Candy Crush, Disney+, etc.).
*   Uninstalls unused system apps (3D Builder, Solitaire).
*   Disables unnecessary background services.

### 3. Gaming (`Modules\Gaming.psm1`)
*   Enables "Ultimate Performance" power plan.
*   Disables Nagle's Algorithm (Network throttling).
*   Prioritizes GPU and CPU for foreground applications.

### 4. Optimize (`Modules\Optimize.psm1`)
*   General system responsiveness tweaks.
*   Disk cleanup and temporary file removal.
*   Explorer and context menu optimizations.

---

## â“ Troubleshooting

**Q: The script closes immediately after opening.**
A: Ensure you have set the execution policy correctly. Try running it from an Administrator PowerShell window using: `.\IlumnulOS.ps1` to see any error messages.

**Q: My CPU/RAM stats show "Detecting...".**
A: The dashboard uses WMI/CIM queries. Ensure the "Windows Management Instrumentation" service is running.

**Q: Can I undo changes?**
A: IlumnulOS creates registry modifications. It is **strongly recommended** to create a **System Restore Point** before running any optimization tool.

---

## âš ï¸ Disclaimer

**Use at your own risk.**
This tool modifies critical system settings, registry keys, and services. While every effort has been made to ensure stability, the developers are not responsible for any system instability, data loss, or boot issues.
*   Always backup your data.
*   Create a System Restore Point.

---

## ðŸ¤ Contributing

Contributions are welcome! Please follow these steps:
1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/NewFeature`).
3.  Commit your changes.
4.  Push to the branch.
5.  Open a Pull Request.

---

## ðŸ“„ License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
