# HWINFO-MCP

A local, read-only MCP server for Windows that exposes HWiNFO sensor readings over standard input/output. It reads HWiNFO's shared-memory interface rather than automating its window.

## Requirements

- Windows and Python 3.10 or newer (standard library only).
- Windows PowerShell 5.1 (`powershell.exe`).
- [HWiNFO](https://www.hwinfo.com/download/) running with Sensors active and **Shared Memory Support** enabled.
- Permission to read HWiNFO's shared-memory mapping and mutex. If Windows denies access, run the client with appropriate permissions; the server does not elevate itself or change security settings.

HWiNFO is a separate product and is not bundled. Its free edition limits shared-memory support to 12 hours per session. Follow its licensing terms. See the [HWiNFO author's instructions for shared memory](https://hwinfo.com/forum/threads/settings-tab-not-opening.11030/).

## Configure an MCP client

Use absolute paths for both Python and the server script. Adapt this example to your client:

```json
{
  "mcpServers": {
    "hwinfo": {
      "command": "C:\\Path\\To\\python.exe",
      "args": ["C:\\Path\\To\\HWINFO-MCP\\hwinfo_mcp.py"]
    }
  }
}
```

Tool: **`hwinfo_snapshot`**, with no arguments. It returns capture time, HWiNFO's polling timestamp, and every published reading's sensor group, name, unit, current, minimum, maximum, and average values.

For a snapshot without an MCP client:

```powershell
python .\hwinfo_mcp.py --snapshot
```

Or export directly using the underlying reader:

```powershell
.\read-hwinfo.ps1 -OutputPath "$env:TEMP\hwinfo-sensors.json"
```

The MCP server uses a temporary output directory and removes it after each call. Protocol responses go to stdout; diagnostics go to stderr. No network listener, background service, scheduled task, or automatic HWiNFO restart is created.

## Interpreting readings

- Only sensors actually published by HWiNFO are available. Battery temperature, fan RPM, and firmware settings may be absent.
- Min/max/average describe HWiNFO's current statistics period, not the machine's lifetime.
- Sleeping or unavailable devices may expose zero or misleading readings. Do not interpret a sleeping GPU's 0 °C as a real temperature.
- Boolean readings use HWiNFO's numeric representation; inspect the unit and current/max fields.
- The server does not validate sensor accuracy or claim that a value named "Total System Power" measures wall-socket consumption.
- Sensor output can contain device identifiers. Review it before sharing.

The reader acquires HWiNFO's mutex while copying a snapshot. It does not write to shared memory, modify hardware settings, control fans, or change power plans.

## Validation

Tested on Windows with Python 3.12 and HWiNFO 8.54: MCP initialization, tool discovery, and live snapshots with more than 390 readings. No proprietary binaries or personal sensor captures are included in this repository.
