# Config file path
$configFile = ".\config.json"

# Load config or exit
if (-Not (Test-Path $configFile)) {
    Write-Error "Missing config file."
    exit 1
}
try {
    $config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
} catch {
    Write-Error "Invalid JSON syntax."
    exit 1
}

# Validate required fields
$requiredFields = @(
    "apiKey","latitude","longitude","sftpHost","sftpPort","sftpUser",
    "sftpKey","remotePath","ffmpegPath","videoDevice","videoSize",
    "font","dateFormat","imagePath","logFile"
)
foreach ($field in $requiredFields) {
    if (-not $config.PSObject.Properties.Name -contains $field) {
        Write-Error "Missing config property: $field"
        exit 1
    }
}

# Set defaults if missing
if (-not $config.minBrightness) { $config | Add-Member NoteProperty minBrightness 40 }
if (-not $config.maxBrightness) { $config | Add-Member NoteProperty maxBrightness 200 }
if (-not $config.maxAttempts)   { $config | Add-Member NoteProperty maxAttempts 5 }

# Log errors
function Write-Log($message) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $config.logFile -Value "[$timestamp] ERROR: $message"
}

# Wind direction
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

# Date info
$now = Get-Date
$timestamp = $now.ToString("yyyyMMdd")
$currentHour = $now.Hour
$currentMinute = $now.Minute
$degree = [char]0x00B0

# Fetch weather
try {
    $forecastUrl = "http://api.openweathermap.org/data/2.5/forecast?lat=$($config.latitude)&lon=$($config.longitude)&appid=$($config.apiKey)&units=metric&lang=it"
    $resp = Invoke-RestMethod -Uri $forecastUrl -UseBasicParsing
    $temp = [math]::Round($resp.list[0].main.temp)
    $humidity = $resp.list[0].main.humidity
    $windSpd = [math]::Round($resp.list[0].wind.speed * 3.6, 1)
    $windDir = Get-WindDirection $resp.list[0].wind.deg
    $desc = $resp.list[0].weather[0].description
    $desc = if ($desc.Length -gt 0) { $desc.Substring(0,1).ToUpper() + $desc.Substring(1) } else { "Non pervenuto" }
    $code = $resp.list[0].weather[0].id
    switch ($code) {
        {$_ -ge 200 -and $_ -lt 300} { $emoji="⛈️"; break }
        {$_ -ge 300 -and $_ -lt 600} { $emoji="🌧️"; break }
        {$_ -ge 600 -and $_ -lt 700} { $emoji="❄️"; break }
        {$_ -ge 700 -and $_ -lt 800} { $emoji="🌫️"; break }
        800                          { $emoji="☀️"; break }
        {$_ -gt 800 -and $_ -lt 900} { $emoji="☁️"; break }
        default                      { $emoji="🌡️" }
    }
}
catch {
    $temp="NA"; $humidity="NA"; $windSpd="NA"; $windDir="?"; $desc="Non pervenuto"; $emoji="❓"
    Write-Log "Failed to fetch weather data: $_"
}

# Text overlays
$weatherText = "🌡️ $temp$degree C  💧 $humidity\\%  💨 $windSpd km/h  🧭 $windDir  $emoji $desc"
$dateText = $now.ToString($config.dateFormat)
$filter = "drawbox=x=0:y=ih-40:w=iw:h=40:color=black@0.5:t=fill," +
          "drawtext=fontfile=$($config.font):text='$weatherText':fontcolor=white:fontsize=20:x=15:y=h-30," +
          "drawtext=fontfile=$($config.font):text='$dateText':fontcolor=white:fontsize=20:x=w-text_w-15:y=h-25"

# Brightness validation loop
$brightness = 255
$attempt = 1
do {
    & "$($config.ffmpegPath)" -hide_banner -loglevel error -y -f dshow -video_size $($config.videoSize) -i video="$($config.videoDevice)" -frames:v 1 -vf $filter "$($config.imagePath)"
    if ($LASTEXITCODE -ne 0) { Write-Log "Failed ffmpeg capture on attempt $attempt."; break }

    $escapedPath = $config.imagePath -replace '\\','/' -replace ':','\:'
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
    } else { break }

    $attempt++
} while ($attempt -le $config.maxAttempts)

# Upload if valid
if ($brightness -ge $config.minBrightness -and $brightness -le $config.maxBrightness) {
    scp -q -P $($config.sftpPort) -i "$($config.sftpKey)" "$($config.imagePath)" "$($config.sftpUser)@$($config.sftpHost):$($config.remotePath)/live.jpg"
    if ($LASTEXITCODE -ne 0) { Write-Log "Failed to upload live image." }

    if (($currentHour -eq 9) -and ($currentMinute -eq 0)) {
        scp -q -P $($config.sftpPort) -i "$($config.sftpKey)" "$($config.imagePath)" "$($config.sftpUser)@$($config.sftpHost):$($config.remotePath)/$timestamp.jpg"
        if ($LASTEXITCODE -ne 0) { Write-Log "Failed to upload 9:00 image." }
    }
}