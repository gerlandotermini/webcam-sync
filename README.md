
# 📸 Webcam Weather Uploader

This PowerShell script captures an image from your USB webcam, overlays the current local weather forecast and date/time, and uploads it to a remote SFTP server. It’s designed to run automatically at regular intervals using Windows Task Scheduler.

## 📦 Setup Instructions

### 1️⃣ Install Dependencies

- **[ffmpeg](https://ffmpeg.org/download.html)**  
  Download and install ffmpeg for Windows. Note the full path to `ffmpeg.exe`.

- **OpenWeatherMap API Key**  
  Create a free account at [openweathermap.org](https://openweathermap.org/api) and generate an API key for accessing the weather data.

## 2️⃣ Set Up Your Configuration

- Copy `config-sample.json` to `config.json`
- Open `config.json` and fill in:
  - Your OpenWeatherMap API key
  - Latitude & longitude (decimal degrees)
  - SFTP server details (host, port, user, key path)
  - Local paths to ffmpeg, fonts, webcam image destination, and log file
  - Video device name and capture resolution

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
  "font": "/Windows/Fonts/arial.ttf",
  "dateFormat": "yyyy-MM-dd HH.mm",
  "imagePath": "C:/Users/you/webcam/webcam.jpg",
  "logFile": "C:/Users/you/webcam/capture.log"
}
```

## 3️⃣ Test the Script

Open PowerShell, navigate to the project folder, and run:

```powershell
.\capture.ps1
```

Check the output image and confirm uploads are working.

## 4️⃣ How to Find Video Device Name and Supported Sizes

List available video devices:

```powershell
& "C:\Path\To\ffmpeg.exe" -list_devices true -f dshow -i dummy
```

List supported resolutions for your device:

```powershell
& "C:\Path\To\ffmpeg.exe" -f dshow -list_options true -i video="Your Device Name"
```

## 📅 Automating with Windows Task Scheduler

To run this script at regular intervals automatically:

### Create a New Task:
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
- Uncheck **Start the task only if the computer is on AC power** (optional)

Click **OK** and enter your Windows password if prompted.

## 📄 Project Structure

```
webcam-weather/
├── capture.ps1               # Main script
├── config-sample.json        # Sample config for users to copy and edit
├── .gitignore                # Prevents config.json, logs, and images from being committed
└── README.md                 # This documentation
```

## 🔄 Example Schedule

| Start Time | End Time | Frequency |
|------------|----------|------------|
| 7:30 AM    | 4:30 PM  | Every 10 min |

## 🌤️ Icon Legend

| Icon | Meaning             |
|:------|:--------------------|
| 🌡️    | Temperature          |
| ⛈️    | Thunderstorm         |
| 🌧️    | Rain / Drizzle       |
| ❄️    | Snow                 |
| 🌫️    | Fog / Mist / Haze    |
| ☀️    | Clear sky            |
| ☁️    | Clouds               |
| 💨    | Wind speed           |
| 🧭    | Wind direction       |
| 💧    | Humidity             |

## 📌 Notes

- `config.json` is excluded from version control via `.gitignore`.
- The script uses OpenWeatherMap’s **5-day / 3-hour forecast API** to retrieve local weather conditions.
- ffmpeg must be installed and your webcam must be detected as a DirectShow device on Windows.
- The script is designed for PowerShell 5.1+ and Windows Task Scheduler.
- Logs are written to a configurable `.log` file for troubleshooting and run history.

## 📃 License

This project is open for personal use and learning. Feel free to adapt and share it — but never publish your API keys or private configuration files.