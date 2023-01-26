param (
    [String] $CHROME_COOKIES,
    [String] $uri,
    [String] $OUTPUT
)
$IWARA_HOME = "https://ecchi.iwara.tv"
# 变量
# $CHROME_COOKIES = ''
$USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36'
# $OUTPUT = 
# $uri = 

if ($OUTPUT[-1] -ne "\") {
    $OUTPUT += "\"
}


function getWebPage {
    param (
        [String] $chromeCookies,
        [String] $uri
    )

    $request = Invoke-WebRequest -Uri $uri -SessionVariable "session" -UserAgent $USER_AGENT
    $chomeCookiesList = $chromeCookies -split "; "
    foreach ($chormeCookie in $chomeCookiesList) {
        $cookieList = $chormeCookie -split "="
        $cookieClass = [System.Net.Cookie]::new($cookieList[0], $cookieList[1])
        $session.Cookies.Add($uri, $cookieClass)
    }
    $request = Invoke-WebRequest -Uri $uri -WebSession $session -UserAgent $USER_AGENT
    
    return $request
}

function downloadAllPageVideos {
    Param (
        [String] $chromeCookies,
        [String] $type,
        [System.DateTime] $lastTime,
        [String] $output,
        $request
    )

    $videoArray = @()
    foreach ($link in $request.Links.href) {
        if (($link -like '/videos/*') -and ($link -notin $videoArray)) {
            $videoArray += $link
            Write-Host $link
            $downloadError = downloadVideo -uri $link -chromeCookies $chromeCookies -type $type -lastDate $lastTime -output $output
            if ($downloadError -eq 3) {
                return 1
            }
            # yt-dlp命令
            # & '.\yt-dlp.exe' --config-location '.\local.conf' -P '.' -f "Source" --dateafter 20221025 $videoURL
        }
    }
    return "INFO:Download all page videos function finished"
}

function getUriParts {
    Param (
        [String] $uri
    )
    $parts = $uri.split('/')
    return $parts
}

function infoRegex {
    param (
        [String] $inputStr,
        [String] $regexStr
    )
    foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($inputStr,$regexStr)) {
        return $match.Value
    }
}

function getDateFromString {
    Param (
        [String] $dateStr
    )
    $date = Get-Date -Date $dateStr
    return $date
}

function getLastDate {
    $dateStr = Get-Content -Path .\LastDate.txt
    $date = getDateFromString -dateStr $dateStr
    return $date
}

function getVideoinfo {
    Param (
        [String] $chromeCookies,
        [String] $uri
    )

    if ($uri[0] -ne "h") {
        $uri = $IWARA_HOME + $uri
    }
    $request = getWebPage -uri $uri -chromeCookies $chromeCookies
    $content = $request.Content
    if (!($content -notmatch "<h1>Private video</h1>")) {
        return 0
    }
    $allInfo = infoRegex -inputStr $content -regexStr '<h1 class="title">(.|\n)*?作成者:.+'
    $userName = infoRegex -inputStr $allInfo -regexStr '(?<=class="username">).*(?=<\/a>)'
    $title = infoRegex -inputStr $allInfo -regexStr '(?<=<h1 class="title">).*(?=<\/h1>)'
    $dateStr = infoRegex -inputStr $allInfo -regexStr '(?<=作成日:).*(?= )'
    $date = getDateFromString -dateStr $dateStr
    return @{"title" = $title; "userName" = $userName; "date" = $date}
}

function stringToFileName {
    param (
        [String] $str
    )
    $result = $str -replace "/", ""
    $result = $result -replace "\\", ""
    $result = $result -replace ":", ""
    $result = $result -replace "\*", ""
    $result = $result -replace '"', ""
    $result = $result -replace "\?", ""
    $result = $result -replace "<", ""
    $result = $result -replace ">", ""
    $result = $result -replace "|", ""
    return $result
}

function downloadVideo {
    Param (
        [String] $uri,
        [String] $chromeCookies,
        [System.DateTime] $lastDate,
        [String] $type,
        [String] $output
    )

    $uriParts = getUriParts -uri $uri
    $videoUri = "https://ecchi.iwara.tv/videos/"
    if ($uriParts -contains "videos") {
        $videoUri += $uriParts[-1]
    } else {
        Write-Host "ERROR:Not a video"
        return 1
    }
    Write-Host $videoUri
    $info = getVideoinfo -uri $uri -chromeCookies $chromeCookies
    if ($info -eq 0) {
        Write-Host "ERROR:Private video"
        return 2
    } elseif (([System.DateTime]::Compare($info["date"], $lastDate) -lt 0) -and ($type -eq "Subscriptions")) {
        Write-Host "ERROR:Date is earlier than last time"
        return 3
    }
    $apiURI = "https://ecchi.iwara.tv/api/video/" + $uriParts[-1]
    $request = Invoke-WebRequest -Uri $apiURI -UserAgent $USER_AGENT
    $jsonArray = (ConvertFrom-Json -InputObject $request.Content)
    $downloadURL = "https:"
    $ext = "."
    foreach ($json in $jsonArray) {
        if ($json.resolution -eq "Source") {
            $downloadURL += $json.uri
            $ext += (infoRegex -inputStr $json.mime -regexStr "(?<=.*\/).*")
            break
        }
    }
    # 输出到作者名文件夹
    $folderName = stringToFileName -str $info["userName"]
    $fileName = stringToFileName -str $info["title"]
    $outputFile = $output + $folderName + "\" + $fileName + $ext
    $outputFolder = $output + $folderName + "\"
    if (!(Test-Path -Path $outputFolder)) {
        Write-Host "ERROE:Path not exitst"
        New-Item -Path $output -Name $folderName -ItemType Directory
        Write-Host "INFO:Make dir end"
    }
    if (Test-Path -Path $outputFile) {
        Write-Host "INFO:Folder Path Succeesfully"
        Write-Host "ERROR:Video has been downloaded"
        return 4
    }
    Write-Host "INFO:Download file:" $outputFile
    Start-BitsTransfer -Source $downloadURL -Destination $outputFile
    return "INFO:Download video function finished"
}

function downloadALlPage {
    param (
        [String] $chromeCookies,
        [System.DateTime] $lastTime,
        [String] $uri,
        [String] $type,
        [String] $output
    )
    
    $request = getWebPage -uri $uri -chromeCookies $chromeCookies
    $page = 1
    while (!($request.Content -notmatch '<a title="次のページへ"')) {
        Write-Host '===================================================================================================================='
        Write-Host ' '
        Write-Host $nextURL
        Write-Host ("Page = " + $page.ToString())
        # 获取下一页
        $nextURL = $IWARA_HOME + (infoRegex -inputStr $request.content -regexStr '(?<=<a title="次のページへ" href=").*(?=">)')
        $page += 1
        $downloadPageError = downloadAllPageVideos -request $request -type $type -lastTime $lastTime -chromeCookies $chromeCookies -output $output
        if (($downloadPageError -eq 1) -and ($type -eq "Subscriptions")) {
            return 1
        }
        $request = getWebPage -uri $nextURL -chromeCookies $chromeCookies
    }
    Write-Host "end:"
    downloadAllPageVideos -request $request -type $type -lastTime $lastTime -chromeCookies $chromeCookies -output $output
    return "INFO:Download all pages function finished"

}

function downloadSubscriptions {
    Param (
        [String] $chromeCookies,
        [System.DateTime] $lastTime,
        [String] $uri,
        [String] $output
    )
    $type = "Subscriptions"
    $downloadError = downloadALlPage -chromeCookies $chromeCookies -lastTime $lastTime -uri $uri -output $output -type $type
    if ($downloadError -eq 0) {
        $newDate = Get-Date
        $newDate = $newDate.AddDays(-1)
        Out-File -FilePath .\LastDate.txt -InputObject $newDate.ToString("yyyy-MM-dd")
    }
    return "INFO:Download subscriptions function finished"
}

function downloadFromUsers {
    param (
        [String] $chromeCookies,
        [System.DateTime] $lastTime,
        [String] $uri,
        [String] $output
    )
    
    $type = "Users"
    $userPage = getWebPage -uri $uri -chromeCookies $chromeCookies
    if ($userPage.Content -notmatch "See all  </a>") {
        downloadAllPageVideos -chromeCookies $chromeCookies -type $type -lastTime $lastTime -output $output -request $userPage
    } else {
        $uri = $IWARA_HOME + (infoRegex -inputStr $userPage.Content -regexStr '(?<=<div class="more-link">[\s]*<a href=").*(?=(">[\s]*See all))')
        downloadALlPage -chromeCookies -$chromeCookies -type $type -lastTime $lastTime -uri $uri -output $output
    }
    return "INFO:Download from users function finished"
}

if (!(Test-Path -Path .\LastDate.txt)) {
    Set-Content -Path .\LastDate.txt -Value "2022-12-01"
}
$LAST_DATE = getLastDate

switch ($uri.split("/")[3]) {
    "subscriptions" {
        downloadSubscriptions -uri $uri -chromeCookies $CHROME_COOKIES -lastTime $LAST_DATE -output $OUTPUT
    }
    "videos" {
        downloadVideo -uri $uri -chromeCookies $CHROME_COOKIES -lastDate $LAST_DATE -type "Video" -output $OUTPUT
    }
    "users" {
        downloadFromUsers -uri $uri -chromeCookies $CHROME_COOKIES -lastTime $LAST_DATE -output $OUTPUT
    }
    Default {
        Write-Host "ERROR:Unsupported URL"
    }
}
