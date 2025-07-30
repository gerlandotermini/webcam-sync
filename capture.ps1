# Webcam capture script with weather overlay and brightness check

# -------------------------------
# Load config
# -------------------------------
$configPath = Join-Path $PSScriptRoot "config.json"
$config = Get-Content $configPath | ConvertFrom-Json

# -------------------------------
# Utility functions
# -------------------------------
function Write-Log {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $config.logFile -Value "$timestamp $message"
}

function Get-WindDirection {
    param([int]$deg)
    switch ($deg) {
        {$_ -ge 337.5 -or $_ -lt 22.5} { return "N" }
        {$_ -ge 22.5 -and $_ -lt 67.5} { return "NE" }
        {$_ -ge 67.5 -and $_ -lt 112.5} { return "E" }
        {$_ -ge 112.5 -and $_ -lt 157.5} { return "SE" }
        {$_ -ge 157.5 -and $_ -lt 202.5} { return "S" }
        {$_ -ge 202.5 -and $_ -lt 247.5} { return "SW" }
        {$_ -ge 247.5 -and $_ -lt 292.5} { return "W" }
        {$_ -ge 292.5 -and $_ -lt 337.5} { return "NW" }
        default { return "?" }
    }
}

# -------------------------------
# Main script logic starts here
# -------------------------------
$now = Get-Date
$timestamp = $now.ToString("yyyyMMdd")
$currentHour = $now.Hour
$currentMinute = $now.Minute
$degree = [char]0x00B0

# Get current weather
try {
    $weatherUrl = "http://api.openweathermap.org/data/2.5/weather?lat=$($config.latitude)&lon=$($config.longitude)&appid=$($config.apiKey)&units=metric&lang=it"
    $resp = Invoke-RestMethod -Uri $weatherUrl -UseBasicParsing
    $temp = [math]::Round($resp.main.temp)
    $humidity = $resp.main.humidity
    $windSpd = [math]::Round($resp.wind.speed * 3.6, 1)
    $windDir = Get-WindDirection $resp.wind.deg
    $desc = $resp.weather[0].description
    $desc = if ($desc.Length -gt 0) { $desc.Substring(0,1).ToUpper() + $desc.Substring(1) } else { "Non pervenuto" }
    $code = $resp.weather[0].id
    switch ($code) {
        {$_ -ge 200 -and $_ -lt 300} { $emoji="⛈️"; break }
        {$_ -ge 300 -and $_ -lt 600} { $emoji="🌧️"; break }
        {$_ -ge 600 -and $_ -lt 700} { $emoji="❄️"; break }
        {$_ -ge 700 -and $_ -lt 800} { $emoji="🌫️"; break }
        800                          { $emoji="☀️"; break }
        {$_ -gt 800 -and $_ -lt 900} { $emoji="☁️"; break }
        default                      { $emoji="🌡️" }
    }
} catch {
    $temp="NA"; $humidity="NA"; $windSpd="NA"; $windDir="?"; $desc="Non pervenuto"; $emoji="❓"
    Write-Log "Failed to fetch weather data: $_"
}

$weatherText = "🌡️ $temp$degree C  💧 $humidity\\%  💨 $windSpd km/h  🧭 $windDir  $emoji $desc"
$dateText = $now.ToString($config.dateFormat)

$filter = "drawbox=x=0:y=ih-40:w=iw:h=40:color=black@0.5:t=fill," +
          "drawtext=fontfile=$($config.font):text='$weatherText':fontcolor=white:fontsize=20:x=15:y=h-30," +
          "drawtext=fontfile=$($config.font):text='$dateText':fontcolor=white:fontsize=20:x=w-text_w-15:y=h-25"

# -------------------------------
# Image capture and brightness check
# -------------------------------
$brightness = 255
$attempt = 1
do {
    & "$($config.ffmpegPath)" -hide_banner -loglevel error -y -f dshow -video_size $($config.videoSize) -i video="$($config.videoDevice)" -frames:v 1 -vf $filter "$($config.imagePath)"
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed ffmpeg capture on attempt $attempt."
        break
    }

    $escapedPath = $config.imagePath -replace '\\', '/'
    $escapedPath = $escapedPath -replace ':', '\:'
    $args = @('-f','lavfi','-i',"movie='$escapedPath',signalstats",'-v','error','-show_entries','frame_tags=lavfi.signalstats.YAVG','-of','default=noprint_wrappers=1:nokey=1')
    $brightnessResult = & ffprobe @args | Out-String
    $brightnessResult = $brightnessResult.Trim()

    if ($brightnessResult -match '^[\d\.]+$') {
        $brightness = [double]$brightnessResult
    } else {
        Write-Log "Failed to parse brightness: $brightnessResult"
        break
    }

    if ($brightness -lt $config.minBrightness -or $brightness -gt $config.maxBrightness) {
        if ($attempt -eq $config.maxAttempts) {
            Write-Log "Brightness $brightness out of range after $($config.maxAttempts) attempts."
        } else {
            Start-Sleep -Seconds 2
        }
    } else {
        break
    }
    $attempt++
} while ($attempt -le $config.maxAttempts)

# -------------------------------
# Upload image if brightness OK
# -------------------------------
if ($brightness -ge $config.minBrightness -and $brightness -le $config.maxBrightness) {
    scp -q -P $($config.sftpPort) -i "$($config.sftpKey)" "$($config.imagePath)" "$($config.sftpUser)@$($config.sftpHost):$($config.remotePath)/live.jpg"
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to upload live image."
    }

    if (($currentHour -eq 9) -and ($currentMinute -eq 0)) {
        scp -q -P $($config.sftpPort) -i "$($config.sftpKey)" "$($config.imagePath)" "$($config.sftpUser)@$($config.sftpHost):$($config.remotePath)/$timestamp.jpg"
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to upload 9:00 image."
        }
    }
}