# Webcam Weather Uploader

This PowerShell script captures an image from your webcam, overlays the current weather forecast and date/time, and uploads it to a remote SFTP server.

## Setup

1. Install [ffmpeg](https://ffmpeg.org/download.html) and note the path to `ffmpeg.exe`.
2. Copy `config-sample.json` to `config.json`.
3. Edit `config.json` with your API key, coordinates, SFTP credentials, and local paths.
4. Run `capture.ps1` via PowerShell or Windows Task Scheduler.

## Notes

- `config.json` is excluded from version control via `.gitignore`.
- Uses OpenWeatherMap 5-day/3-hour forecast API.
- Script requires PowerShell 5.1+.

