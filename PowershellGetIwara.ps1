[CmdletBinding()]
param(
    [Stirng]$chromeCookies
)
# 填自己的
$userAgent = ''

$uri = "https://ecchi.iwara.tv/subscriptions"
$IWARA_HOME = "https://ecchi.iwara.tv"
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

function infoRegex {
    param (
        [String] $inputStr,
        [String] $regexStr
    )
    foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($inputStr,$regexStr)) {
        return $match.Value
    }
}

function downloadVideo {
    Param (
        [Microsoft.PowerShell.Commands.HtmlWebResponseObject] $request
    )

    $videoArray = @()
    foreach ($link in $request.Links.href) {
        if (($link -like '/videos/*') -and ($link -notin $videoArray)) {
            $videoURL = $IWARA_HOME + $link
            $videoArray.add($link)
            Write-Host $videoURL
            # yt-dlp命令
            & '.\yt-dlp.exe' --config-location '.\local.conf' -P '.' -f "Source" --dateafter 20221025 $videoURL
        }
    }
}


$request = getWebPage -chromeCookies $chromeCookies -uri $uri
$page = 1
while (!($request.Content -notmatch '<a title="次のページへ"')) {
    Write-Host '===================================================================================================================='
    Write-Host ' '
    Write-Host $nextURL
    Write-Host ("Page = " + $page.ToString())
    $nextURL = $IWARA_HOME + (infoRegex -inputStr $request.content -regexStr '(?<=<a title="次のページへ" href=").*(?=">)')
    $page += 1
    downloadVideo -request $request
    $request = getWebPage -chromeCookies $chromeCookies -uri $nextURL
}

Write-Host "end:"
downloadVideo -request $request
