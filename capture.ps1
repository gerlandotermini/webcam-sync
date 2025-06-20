# Config file path
$configFile = ".\config.json"

# Check if config file exists
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

# Get current date and time
$now = Get-Date
$timestamp = $now.ToString("yyyyMMdd")
$currentHour = $now.Hour
$currentMinute = $now.Minute
$degree = [char]0x00B0

# Weather API URL
$forecastUrl = "http://api.openweathermap.org/data/2.5/forecast?lat=$($config.latitude)&lon=$($config.longitude)&appid=$($config.apiKey)&units=metric&lang=it"

# Get forecast JSON
try {
    $forecastResponse = Invoke-RestMethod -Uri $forecastUrl -UseBasicParsing

    if ($forecastResponse.list -and $forecastResponse.list.Count -gt 0) {
        $currentTemp = [math]::Round($forecastResponse.list[0].main.temp)
        $descRaw = $forecastResponse.list[0].weather[0].description
        if ($descRaw.Length -gt 0) {
            $forecastDesc = $descRaw.Substring(0,1).ToUpper() + $descRaw.Substring(1)
        } else {
            $forecastDesc = "Non pervenuto"
        }
    } else {
        $currentTemp = "NA"
        $forecastDesc = "Non pervenuto"
    }
}
catch {
    $currentTemp = "NA"
    $forecastDesc = "Non pervenuto"
}

# Build overlay texts
$weatherText = "$currentTemp$degree C - $forecastDesc"
$dateTimeText = $now.ToString($config.dateFormat)

# Build FFmpeg filter
$filter = "drawtext=fontfile=$($config.font):text='$weatherText':fontcolor=white:fontsize=20:box=1:boxcolor=black@0.5:boxborderw=10:x=15:y=h-text_h-15," +
          "drawtext=fontfile=$($config.font):text='$dateTimeText':fontcolor=white:fontsize=20:box=1:boxcolor=black@0.5:boxborderw=10:x=w-text_w-15:y=h-text_h-15"

# Capture image
& "$($config.ffmpegPath)" -hide_banner -loglevel error -y -f dshow -video_size $($config.videoSize) -i video="$($config.videoDevice)" -frames:v 1 -vf $filter "$($config.imagePath)"

# Initialize log
$logMessage = "$($now.ToString("yyyy-MM-dd HH:mm")) | "

# Upload if capture succeeded
if ($LASTEXITCODE -eq 0) {
    scp -q -P $($config.sftpPort) -i "$($config.sftpKey)" "$($config.imagePath)" "$($config.sftpUser)@$($config.sftpHost):$($config.remotePath)/live.jpg"
    $logMessage += "Uploaded live.jpg"

    if (($currentHour -eq 9) -and ($currentMinute -eq 0)) {
        scp -q -P $($config.sftpPort) -i "$($config.sftpKey)" "$($config.imagePath)" "$($config.sftpUser)@$($config.sftpHost):$($config.remotePath)/$timestamp.jpg"
        $logMessage += " and $timestamp.jpg"
    }
}
else {
    $logMessage += "Failed to capture image"
}

# Write log entry
Add-Content -Path $($config.logFile) -Value $logMessage