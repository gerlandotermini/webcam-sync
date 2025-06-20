# Config file path
$configFile = ".\config.json"

# Load config file, or exit if missing
if (-Not (Test-Path $configFile)) {
    Write-Error "Configuration file $configFile not found. Please create it from config-sample.json."
    exit 1
}

# Load config
try {
    $config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse $configFile. Check its JSON syntax."
    exit 1
}

# Validate required fields
$requiredFields = @(
    "apiKey", "latitude", "longitude", "sftpHost", "sftpPort", "sftpUser",
    "sftpKey", "remotePath", "ffmpegPath", "videoDevice", "videoSize",
    "font", "dateFormat", "imagePath", "logFile"
)

foreach ($field in $requiredFields) {
    if (-not $config.PSObject.Properties.Name -contains $field) {
        Write-Error "Missing required config property: $field"
        exit 1
    }
}

# Logging helper for errors only
function Write-Log($message) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $config.logFile -Value "[$timestamp] ERROR: $message"
}

# Function to convert wind degrees to compass direction
function Get-WindDirection($deg) {
    if ($deg -ge 337.5 -or $deg -lt 22.5) { return "Nord" }
    elseif ($deg -ge 22.5 -and $deg -lt 67.5) { return "Nord-Est" }
    elseif ($deg -ge 67.5 -and $deg -lt 112.5) { return "Est" }
    elseif ($deg -ge 112.5 -and $deg -lt 157.5) { return "Sud-Est" }
    elseif ($deg -ge 157.5 -and $deg -lt 202.5) { return "Sud" }
    elseif ($deg -ge 202.5 -and $deg -lt 247.5) { return "Sud-Ovest" }
    elseif ($deg -ge 247.5 -and $deg -lt 292.5) { return "Ovest" }
    elseif ($deg -ge 292.5 -and $deg -lt 337.5) { return "Nord-Ovest" }
    else { return "?" }
}

# Get current date and time
$now = Get-Date
$timestamp = $now.ToString("yyyyMMdd")
$currentHour = $now.Hour
$currentMinute = $now.Minute
$degree = [char]0x00B0

# Weather API URL
$forecastUrl = "http://api.openweathermap.org/data/2.5/forecast?lat=$($config.latitude)&lon=$($config.longitude)&appid=$($config.apiKey)&units=metric&lang=it"

# Fetch forecast
try {
    $forecastResponse = Invoke-RestMethod -Uri $forecastUrl -UseBasicParsing

    $currentTemp   = [math]::Round($forecastResponse.list[0].main.temp)
    $forecastCode  = $forecastResponse.list[0].weather[0].id
    $forecastDesc  = if ($forecastResponse.list[0].weather[0].description.Length -gt 0) { 
        $forecastResponse.list[0].weather[0].description.Substring(0,1).ToUpper() + $forecastResponse.list[0].weather[0].description.Substring(1) 
    } else { 
        "Non pervenuto" 
    }
    $windSpeed     = [math]::Round($forecastResponse.list[0].wind.speed * 3.6, 1)  # Convert m/s to km/h
    $windDeg       = $forecastResponse.list[0].wind.deg
    $windDir       = Get-WindDirection $windDeg
    $humidity      = $forecastResponse.list[0].main.humidity

    switch ($forecastCode) {
        { $_ -ge 200 -and $_ -lt 300 } { $emoji = "⛈️"; break }
        { $_ -ge 300 -and $_ -lt 600 } { $emoji = "🌧️"; break }
        { $_ -ge 600 -and $_ -lt 700 } { $emoji = "❄️"; break }
        { $_ -ge 700 -and $_ -lt 800 } { $emoji = "🌫️"; break }
        800                            { $emoji = "☀️"; break }
        { $_ -gt 800 -and $_ -lt 900 } { $emoji = "☁️"; break }
        default                        { $emoji = "🌡️" }
    }
}
catch {
    $currentTemp   = "NA"
    $forecastDesc  = "Non pervenuto"
    $windSpeed     = "NA"
    $windDir       = "?"
    $humidity      = "NA"
    $emoji         = "❓"
    Write-Log "Failed to fetch weather data: $_"
}

# Build weather text line with emojis and wind direction
$weatherText = "🌡️ $currentTemp$degree C   💧 $humidity\\%   💨 $windSpeed km/h    🧭 $windDir   $emoji $forecastDesc"
$dateTimeText = $now.ToString($config.dateFormat)

# Build ffmpeg drawtext filter with one translucent black bar background
$filter = "drawbox=x=0:y=ih-40:w=iw:h=40:color=black@0.5:t=fill," +
          "drawtext=fontfile=$($config.font):text='$weatherText':fontcolor=white:fontsize=20:x=15:y=h-30," +
          "drawtext=fontfile=$($config.font):text='$dateTimeText':fontcolor=white:fontsize=20:x=w-text_w-15:y=h-25"

# Capture image
& "$($config.ffmpegPath)" -hide_banner -loglevel error -y -f dshow -video_size $($config.videoSize) -i video="$($config.videoDevice)" -frames:v 1 -vf $filter "$($config.imagePath)"

if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to capture image with ffmpeg."
}

# Upload live image
scp -q -P $($config.sftpPort) -i "$($config.sftpKey)" "$($config.imagePath)" "$($config.sftpUser)@$($config.sftpHost):$($config.remotePath)/live.jpg"
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to upload live image to server."
}

# Upload timestamped image at 9:00 AM
if (($currentHour -eq 9) -and ($currentMinute -eq 0)) {
    scp -q -P $($config.sftpPort) -i "$($config.sftpKey)" "$($config.imagePath)" "$($config.sftpUser)@$($config.sftpHost):$($config.remotePath)/$timestamp.jpg"
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to upload timestamped image at 9:00 AM."
    }
}