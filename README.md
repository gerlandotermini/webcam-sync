
# 📸 Webcam Weather Uploader

This PowerShell script captures an image from your USB webcam, overlays the current local weather forecast and date/time, and uploads it to a remote SFTP server. It’s designed to run automatically at regular intervals using Windows Task Scheduler.

---

## 📦 Setup Instructions

### 1️⃣ Install Dependencies

- **[ffmpeg](https://ffmpeg.org/download.html)**  
  Download and install ffmpeg for Windows. Note the full path to `ffmpeg.exe`.

- **OpenWeatherMap API Key**  
  Create a free account at [openweathermap.org](https://openweathermap.org/api) and generate an API key for accessing the weather data.

---

## 2️⃣ Set Up Your Configuration

- Copy `config-sample.json` to `config.json`
- Open `config.json` and fill in:
  - Your OpenWeatherMap API key
  - Latitude & longitude (decimal degrees)
  - SFTP server details (host, port, user, key path)
  - Local paths to ffmpeg, fonts, and webcam image destination
  - Webcam device name and capture resolution

**Example:**
```json
{
  "apiKey": "your_api_key_here",
  "latitude": "40.123",
  "longitude": "-73.123",
  "sftpHost": "your.server.com",
  "sftpPort": "22",
  "sftpUser": "your_username",
  "sftpKey": "C:/Users/you/.ssh/id_rsa",
  "remotePath": "~/public_html/wp-content/uploads/webcam",
  "ffmpegPath": "C:/Program Files/ffmpeg/bin/ffmpeg.exe",
  "videoDevice": "USB Video Device",
  "videoSize": "960x720",
  "fontEmoji": "/Windows/Fonts/seguiemj.ttf",
  "fontDate": "/Windows/Fonts/cour.ttf",
  "dateFormat": "yyyy-MM-dd HH.mm",
  "imagePath": "C:/Users/you/webcam/webcam.jpg"
}
```

**Notes:**
- `videoDevice` is the exact name of your webcam as detected by ffmpeg.
- `videoSize` sets the image resolution (common values: "1280x720", "960x720", "640x480").

---

## 📷 How to Find Your Webcam Device Name and Supported Resolutions

### 📌 List Available Video Devices

Open a Command Prompt (or PowerShell) and run:

```
"C:\Program Files\ffmpeg\bin\ffmpeg.exe" -list_devices true -f dshow -i dummy
```

Look for a section like:
```
[dshow @ 0000020...] DirectShow video devices
[dshow @ 0000020...]  "USB Video Device"
[dshow @ 0000020...]  "Logitech HD Webcam C270"
```

Copy the exact device name into your `config.json` under the `"videoDevice"` key.

### 📌 List Supported Resolutions for a Device

To see supported resolutions, run:

```
"C:\Program Files\ffmpeg\bin\ffmpeg.exe" -f dshow -list_options true -i video="USB Video Device"
```

Replace `"USB Video Device"` with your actual device name.

Example output:
```
[dshow @ ...]   960x720
[dshow @ ...]   1280x720
[dshow @ ...]   640x480
```

Pick a resolution and enter it in your `config.json` under `"videoSize"`.

---

## 📅 Automating with Windows Task Scheduler

To run this script automatically at regular intervals:

**Create a New Task:**
1. Press `Windows + R`, type `taskschd.msc`, and press Enter.
2. Click **Create Task**

**General Tab:**
- Name the task (e.g. `Webcam Weather Uploader`)
- Choose **Run whether user is logged on or not**
- Check **Run with highest privileges**

**Triggers Tab:**
- Click **New**
- Begin task: `On a schedule`
- Daily schedule
- Start at `7:30 AM`
- Repeat task every `10 minutes`
- For a duration of `9 hours` (until `4:30 PM`)

**Actions Tab:**
- Click **New**
- Action: `Start a program`
- Program/script:
  ```powershell
  powershell.exe
  ```
- Add arguments:
  ```powershell
  -ExecutionPolicy Bypass -File "C:\Path\To\webcam-weather\capture.ps1"
  ```
- Start in:
  ```
  C:\Path\To\webcam-weather
  ```

**Conditions Tab:**
- (Optional) Uncheck **Start the task only if the computer is on AC power**

Click **OK** and enter your Windows password if prompted.

---

## 📄 Project Structure

```
webcam-weather/
├── capture.ps1
├── config-sample.json
├── .gitignore
└── README.md
```

---

## 🔄 Example Schedule

| Start Time | End Time | Frequency |
|------------|----------|------------|
| 7:30 AM    | 4:30 PM  | Every 10 min |

---

## 📌 Notes

- `config.json` is excluded from version control via `.gitignore`.
- The script uses OpenWeatherMap’s **5-day / 3-hour forecast API**.
- ffmpeg must be installed and your webcam must be a DirectShow device.
- Compatible with PowerShell 5.1+ and Windows Task Scheduler.

---

## 📃 License

Open for personal use and learning. Feel free to adapt and share — never publish your API keys or private config files.
