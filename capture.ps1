# Get current date and time
$now = Get-Date
$timestamp = $now.ToString("yyyyMMdd")
$currentHour = $now.Hour
$currentMinute = $now.Minute

# Weather API setup
$apiKey = "65e99f161dc951398de05706ced3668d"
$lat = "40.7587"
$lon = "-74.9799"
$degree = [char]0x00B0
$forecastUrl = "http://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=it"

# Get forecast JSON
try {
    $forecastResponse = Invoke-RestMethod -Uri $forecastUrl -UseBasicParsing
    $currentTemp = [math]::Round($forecastResponse.list[0].main.temp)

    $weatherCode = $forecastResponse.list[0].weather[0].id
    $descRaw = $forecastResponse.list[0].weather[0].description
    if ($descRaw.Length -gt 0) {
        $forecastDesc = $descRaw.Substring(0,1).ToUpper() + $descRaw.Substring(1)
    }
    else {
        $forecastDesc = "Non pervenuto"
    }

    # Map weather codes to emoji
    switch ($weatherCode) {
        { $_ -ge 200 -and $_ -lt 300 } { $emoji = "⛈️"; break }    # Thunderstorm
        { $_ -ge 300 -and $_ -lt 600 } { $emoji = "🌧️"; break }    # Rain and Drizzle
        { $_ -ge 600 -and $_ -lt 700 } { $emoji = "❄️"; break }    # Snow
        { $_ -ge 700 -and $_ -lt 800 } { $emoji = "🌫️"; break }    # Atmosphere (fog, mist)
        800 { $emoji = "☀️"; break }                               # Clear
        801 { $emoji = "🌤️"; break }                               # Few clouds
        { $_ -gt 801 -and $_ -lt 805 } { $emoji = "☁️"; break }    # Clouds
        default { $emoji = "" }
    }
} catch {
    $currentTemp = "NA"
    $forecastDesc = "Non pervenuto"
    $emoji = ""
}

# Build overlay texts with emoji
$weatherText = "$currentTemp${degree}C   $emoji $forecastDesc"
$dateTimeText = $now.ToString("yyyy-MM-dd HH.mm")

# Build FFmpeg filter with emoji font for weather, Courier New for datetime
$filter = "drawtext=fontfile=/Windows/Fonts/seguiemj.ttf:text='$weatherText':fontcolor=white:fontsize=24:box=1:boxcolor=black@0.5:boxborderw=5:x=10:y=h-text_h-10," +
          "drawtext=fontfile=/Windows/Fonts/seguiemj.ttf:text='$dateTimeText':fontcolor=white:fontsize=24:box=1:boxcolor=black@0.5:boxborderw=5:x=w-text_w-10:y=h-text_h-10"

# Capture image using ffmpeg (quiet, overwrite)
& "C:\Program Files\ffmpeg\bin\ffmpeg.exe" -hide_banner -loglevel error -y -f dshow -video_size 960x720 -i video="USB Video Device" -frames:v 1 -vf $filter "C:\Users\gerla\Misc\webcam/live.jpg"

# Check ffmpeg exit code
if ($LASTEXITCODE -eq 0) {
    # Always upload the live image
    scp -q -P2299 -i "C:\Users\gerla\.ssh\id_rsa" "C:\Users\gerla\Misc\webcam/live.jpg" "duechiac@65.108.143.244:~/public_html/content/uploads/webcam/live.jpg"

    # Upload timestamped image only at 9:00 AM sharp
    if (($currentHour -eq 9) -and ($currentMinute -eq 0)) {
        scp -q -P2299 -i "C:\Users\gerla\.ssh\id_rsa" "C:\Users\gerla\Misc\webcam/live.jpg" "duechiac@65.108.143.244:~/public_html/content/uploads/webcam/$timestamp.jpg"
    }
} else {
    Write-Output "ffmpeg failed"
}
