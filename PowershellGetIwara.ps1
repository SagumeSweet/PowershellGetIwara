[CmdletBinding()]
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
    [CmdletBinding()]param (
        [String] $chromeCookies,
        [String] $uri
    )
    Write-Host "INFO:开始使用cookie获取网页"
    $request = Invoke-WebRequest -Uri $uri -SessionVariable "session" -UserAgent $USER_AGENT
    $chomeCookiesList = $chromeCookies -split "; "
    foreach ($chormeCookie in $chomeCookiesList) {
        $cookieList = $chormeCookie -split "="
        $cookieClass = [System.Net.Cookie]::new($cookieList[0], $cookieList[1])
        $session.Cookies.Add($uri, $cookieClass)
    }
    $request = Invoke-WebRequest -Uri $uri -WebSession $session -UserAgent $USER_AGENT
    Write-Host "INFO:使用cookie获取网页结束"
    return $request
}

function downloadAllPageVideos {
    [CmdletBinding()]Param (
        [String] $chromeCookies,
        [String] $type,
        [System.DateTime] $lastTime,
        [String] $output,
        $request
    )

    Write-Host "INFO:开始下载单页全部视频"
    $videoArray = @()
    foreach ($link in $request.Links.href) {
        if (($link -like '/videos/*') -and ($link -notin $videoArray)) {
            $videoArray += $link
            Write-Host $link
            $downloadError = downloadVideo -uri $link -chromeCookies $chromeCookies -type $type -lastDate $lastTime -output $output
            if ($downloadError -eq 4) {
                Write-Host "INFO:下载单页全部视频结束"
                return 1
            }
            # yt-dlp命令
            # & '.\yt-dlp.exe' --config-location '.\local.conf' -P '.' -f "Source" --dateafter 20221025 $videoURL
        }
    }
    return "INFO:下载单页全部视频结束"
}

function getUriParts {
    [CmdletBinding()]Param (
        [String] $uri
    )
    $parts = $uri.split('/')
    return $parts
}

function infoRegex {
    [CmdletBinding()]param (
        [String] $inputStr,
        [String] $regexStr
    )
    foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($inputStr,$regexStr)) {
        return $match.Value
    }
}

function getDateFromString {
    [CmdletBinding()]Param (
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
    [CmdletBinding()]Param (
        [String] $chromeCookies,
        [String] $uri
    )
    Write-Host "INFO:开始获取视频信息"
    if ($uri[0] -ne "h") {
        $uri = $IWARA_HOME + $uri
    }
    $request = getWebPage -uri $uri -chromeCookies $chromeCookies
    $content = $request.Content
    if (!($content -notmatch "<h1>Private video</h1>")) {
        return 1
    }
    $allInfo = infoRegex -inputStr $content -regexStr '<h1 class="title">(.|\n)*?作成者:.+'
    if (!($allInfo)) {
        return 2
    }
    $userName = infoRegex -inputStr $allInfo -regexStr '(?<=class="username">).*(?=<\/a>)'
    $title = infoRegex -inputStr $allInfo -regexStr '(?<=<h1 class="title">).*(?=<\/h1>)'
    $dateStr = infoRegex -inputStr $allInfo -regexStr '(?<=作成日:).*(?= )'
    $date = getDateFromString -dateStr $dateStr
    Write-Host "INFO:获取视频信息结束"
    return @{"title" = $title; "userName" = $userName; "date" = $date}
}

function stringToFileName {
    [CmdletBinding()]param (
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

function getRequest {
    [CmdletBinding()]param (
        [String] $uri,
        $session
    )
    Write-Host "INFO:开始获取网页"
    for ($i = 0; $i -lt 3;i++) {
        try {
            $request = Invoke-WebRequest -Uri $uri -UserAgent $USER_AGENT
        } catch {
            Write-Host "ERROR:获取网页失败，正在重试（"($i + 1)"/3)"
            continue
        }
        Write-Host "INFO:获取网页结束"
        return $request
    }
    Write-Host "ERROR:获取网页失败"
    return 1
}

function downloadVideo {
    [CmdletBinding()]Param (
        [String] $uri,
        [String] $chromeCookies,
        [System.DateTime] $lastDate,
        [String] $type,
        [String] $output
    )

    Write-Host "INFO:开始下载视频"
    $uriParts = getUriParts -uri $uri
    $videoUri = "https://ecchi.iwara.tv/videos/"
    if ($uriParts -contains "videos") {
        $videoUri += $uriParts[-1]
    } else {
        Write-Host "ERROR:Not a video"
        Write-Host "INFO:下载视频结束"
        return 1
    }
    Write-Host $videoUri
    $info = getVideoinfo -uri $uri -chromeCookies $chromeCookies
    if ($info -eq 1) {
        Write-Host "ERROR:Private video"
        Write-Host "INFO:下载视频结束"
        return 2
    } elseif ($info -eq 2) {
        Write-Host "ERROR:页面无内容"
        Write-Host "INFO:下载视频结束"
        return 3
    } elseif (($type -eq "Subscriptions") -and ([System.DateTime]::Compare($info["date"], $lastDate) -lt 0)) {
        Write-Host "ERROR:日期比规定日期早"
        Write-Host "INFO:下载视频结束"
        return 4
    }
    $apiURI = "https://ecchi.iwara.tv/api/video/" + $uriParts[-1]
    Write-Host "INFO:开始获取api网页"
    $request = getRequest -uri $apiURI
    if ($request -eq 1) {
        Write-Host "ERROR:获取api页面失败"
        Write-Host "INFO:下载视频结束"
        return 5
    }
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
    Write-Host $info["title"]
    $folderName = stringToFileName -str $info["userName"]
    $fileName = stringToFileName -str $info["title"]
    $outputFile = $output + $folderName + "\" + $fileName + $ext
    $outputFolder = $output + $folderName + "\"
    if (!(Test-Path -Path $outputFolder)) {
        Write-Host "INFO:文件夹未创建，正在创建"
        New-Item -Path $output -Name $folderName -ItemType Directory
        Write-Host "INFO:文件夹创建完成"
    }
    if (Test-Path -Path $outputFile) {
        Write-Host "INFO:文件夹路径完整"
        Write-Host "ERROR:视频已下载"
        return "INFO:下载视频结束"
    }
    Write-Host "INFO:Download file:" $outputFile
    Start-BitsTransfer -Source $downloadURL -Destination $outputFile
    return "INFO:下载视频结束"
}

function downloadALlPage {
    [CmdletBinding()]param (
        [String] $chromeCookies,
        [System.DateTime] $lastTime,
        [String] $uri,
        [String] $type,
        [String] $output
    )
    
    Write-Host "INFO:开始下载全部页面"
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
            Write-Host "INFO:下载全部页面结束"
            return 1
        }
        $request = getWebPage -uri $nextURL -chromeCookies $chromeCookies
    }
    Write-Host "end:"
    downloadAllPageVideos -request $request -type $type -lastTime $lastTime -chromeCookies $chromeCookies -output $output
    return "INFO:下载全部页面结束"

}

function downloadSubscriptions {
    [CmdletBinding()]Param (
        [String] $chromeCookies,
        [System.DateTime] $lastTime,
        [String] $uri,
        [String] $output
    )
    $type = "Subscriptions"
    $downloadError = downloadALlPage -chromeCookies $chromeCookies -lastTime $lastTime -uri $uri -output $output -type $type
    if ($downloadError -eq "INFO:Download all pages function finished") {
        $newDate = Get-Date
        $newDate = $newDate.AddDays(-1)
        Out-File -FilePath .\LastDate.txt -InputObject $newDate.ToString("yyyy-MM-dd")
    }
    return "INFO:Download subscriptions function finished"
}

function downloadFromUsers {
    [CmdletBinding()]param (
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
