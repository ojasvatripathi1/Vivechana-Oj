$channels = @(
    @{name="Aaj Tak"; handle="aajtak"},
    @{name="ABP News"; handle="abpnewshindi"},
    @{name="India TV"; handle="indiatv"},
    @{name="Zee News"; handle="ZeeNews"},
    @{name="NDTV Hindi"; handle="ndtvhindi"},
    @{name="Republic Bharat"; handle="RepublicBharat"}
)

foreach ($ch in $channels) {
    $url = "https://www.youtube.com/@$($ch.handle)"
    try {
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.Method = "GET"
        $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        $req.Timeout = 15000
        $resp = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $content = $reader.ReadToEnd()
        $reader.Close()
        $resp.Close()
        
        # Try to find channelId
        $match = [regex]::Match($content, '"channelId":"(UC[^"]{22})"')
        if ($match.Success) {
            $id = $match.Groups[1].Value
            Write-Host "$($ch.name) (@$($ch.handle)): $id"
        } else {
            # Try alternate pattern
            $match2 = [regex]::Match($content, '"externalId":"(UC[^"]{22})"')
            if ($match2.Success) {
                $id = $match2.Groups[1].Value
                Write-Host "$($ch.name) (@$($ch.handle)) [alt]: $id"
            } else {
                Write-Host "$($ch.name) (@$($ch.handle)): NOT FOUND"
            }
        }
    } catch {
        Write-Host "$($ch.name): ERROR - $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 1
}
