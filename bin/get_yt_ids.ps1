$channels = @{
    "aajtak" = "https://www.youtube.com/@aajtak"
    "abpnewsabhay" = "https://www.youtube.com/@abpnewsabhay"
    "indiatv" = "https://www.youtube.com/@indiatv"
    "zeenews" = "https://www.youtube.com/@zeenews"
}

foreach ($name in $channels.Keys) {
    $url = $channels[$name]
    try {
        $content = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15).Content
        $match = [regex]::Match($content, '"channelId":"(UC[^"]+)"')
        if ($match.Success) {
            $id = $match.Groups[1].Value
            Write-Host "$name : $id"
            # Test RSS
            $rssUrl = "https://www.youtube.com/feeds/videos.xml?channel_id=$id"
            $rss = Invoke-WebRequest -Uri $rssUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
            Write-Host "  RSS Status: $($rss.StatusCode)"
        } else {
            Write-Host "$name : channelId NOT FOUND in page"
        }
    } catch {
        Write-Host "$name : ERROR - $_"
    }
}
