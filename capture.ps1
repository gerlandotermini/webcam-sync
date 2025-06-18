# Load config from JSON file
$config = Get-Content -Raw -Path ".\config.json" | ConvertFrom-Json

# Get current date and time
$now = Get-Date
$timestamp = $now.ToString("yyyyMMdd")
$currentHour = $now.Hour
$currentMinute = $now.Minute

# Degree character
$degree = [char]0x00B0

# Weather API URL
$forecastUrl = "http://api.openweathermap.org/data/2.5/forecast?lat=$($config.latitude)&lon=$($config.longitude)&appid=$($config.apiKey)&units=metric&lang=it"

# Get forecast JSON
try {
    $forecastResponse = Invoke-RestMethod -Uri $forecastUrl -UseBasicParsing
    $currentTemp = [math]::Round($forecastResponse.list[0].main.temp)

    $weatherCode = $forecastResponse.list[0].weather[0].id
    $descRaw = $forecastResponse.list[0].weather[0].description
    if ($descRaw.Length -gt 0) {
        $forecastDesc = $descRaw.Substring(0,1).ToUpper() + $descRaw.Substring(1)
    } else {
        $forecastDesc = "Non pervenuto"
    }

    # Map weather codes to emoji
    switch ($weatherCode) {
        { $_ -ge 200 -and $_ -lt 300 } { $emoji = [char]0x26C8; break }
        { $_ -ge 300 -and $_ -lt 600 } { $emoji = [char]0x1F327; break }
        { $_ -ge 600 -and $_ -lt 700 } { $emoji = [char]0x2744; break }
        { $_ -ge 700 -and $_ -lt 800 } { $emoji = [char]0x1F32B; break }
        800 { $emoji = [char]0x2600; break }
        801 { $emoji = [char]0x1F324; break }
        { $_ -gt 801 -and $_ -lt 805 } { $emoji = [char]0x2601; break }
        default { $emoji = "" }
    }
}
catch {
    $currentTemp = "NA"
    $forecastDesc = "Non pervenuto"
    $emoji = ""
}

# Build overlay texts
$weatherText = "$emoji $currentTemp$degree C - $forecastDesc"
$dateTimeText = $now.ToString($config.dateFormat)

# Build FFmpeg filter with fonts from config
$filter = "drawtext=fontfile=$($config.fontEmoji):text='$weatherText':fontcolor=white:fontsize=24:box=1:boxcolor=black@0.5:boxborderw=5:x=10:y=h-text_h-10," +
          "drawtext=fontfile=$($config.fontDate):text='$dateTimeText':fontcolor=white:fontsize=24:box=1:boxcolor=black@0.5:boxborderw=5:x=w-text_w-10:y=h-text_h-10"

# Capture image using ffmpeg (quiet, overwrite)
& "$($config.ffmpegPath)" -hide_banner -loglevel error -y -f dshow -video_size 960x720 -i video="USB Video Device" -frames:v 1 -vf $filter "$($config.imagePath)"

# Check ffmpeg exit code
if ($LASTEXITCODE -eq 0) {
    # Always upload the live image
    scp -q -P $($config.sftpPort) -i "$($config.sftpKey)" "$($config.imagePath)" "$($config.sftpUser)@$($config.sftpHost):$($config.remotePath)/live.jpg"

    # Upload timestamped image only at 9:00 AM sharp
    if (($currentHour -eq 9) -and ($currentMinute -eq 0)) {
        scp -q -P $($config.sftpPort) -i "$($config.sftpKey)" "$($config.imagePath)" "$($config.sftpUser)@$($config.sftpHost):$($config.remotePath)/$timestamp.jpg"
    }
} else {
    Write-Output "Could not save image from webcam."
}