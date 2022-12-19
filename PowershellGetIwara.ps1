# cookie和UserAgent变量
$chromeCookies = ''
$userAgent = ''

$uri = "https://ecchi.iwara.tv/subscriptions"

function getWebPage {
    param (
        [String] $chromeCookies,
        [String] $uri
    )

    $request = Invoke-WebRequest -Uri $uri -SessionVariable "session" -UserAgent $userAgent
    $chomeCookiesList = $chromeCookies -split "; "
    foreach ($chormeCookie in $chomeCookiesList) {
        $cookieList = $chormeCookie -split "="
        $cookieClass = [System.Net.Cookie]::new($cookieList[0], $cookieList[1])
        $session.Cookies.Add($uri, $cookieClass)
    }
    $request = Invoke-WebRequest -Uri $uri -WebSession $session -UserAgent $userAgent
    
    return $request
}

function downloadVideo {
    Param (
        [Microsoft.PowerShell.Commands.HtmlWebResponseObject] $request
    )

    [System.Collections.ArrayList]$videoArray = 'a', 'b'
    foreach ($link in $request.Links.href) {
        if (($link -like '/videos/*') -and ($link -notin $videoArray)) {
            $videoURL = "https://ecchi.iwara.tv" + $link
            $videoArray.add($link)
            Write-Host $videoURL
            # yt-dlp命令
            & '.\yt-dlp.exe' --config-location '.\local.conf' -P '.' -f "Source" --dateafter 20221025 $videoURL
        }
    }
}


$request = getWebPage -chromeCookies $chromeCookies -uri $uri
$page = 1
while ($request.Content -notmatch '<li class="pager-next last">&nbsp;</li>') {
    Write-Host '===================================================================================================================='
    Write-Host ' '
    Write-Host $nextURL
    Write-Host ("Page = " + $page.ToString())
    $nextURL = ("https://ecchi.iwara.tv/subscriptions?page=" + $page.ToString())
    $page += 1
    downloadVideo -request $request
    $request = getWebPage -chromeCookies $chromeCookies -uri $nextURL
}

Write-Host "end:"
downloadVideo -request $request
