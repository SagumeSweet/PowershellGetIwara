# 通过powershell批量下载iwara(R18)订阅用户的视频

## 使用方法  

+ 先把yt-dlp装上，配置好yt-dlp设置和脚本内的yt-dlp命令
+ `powershell *.ps1 -chromeCookies cookie -userAgent UserAgent`  
直接在脚本里设置变量也可
+ cookie和useragent从浏览器直接复制即可  

## 如何实现的

+ 通过cookie登录，yt-dlp批量下载关注更新的视频，筛选通过yt-dlp配置filter  
+ 访问subscriptions页面获取视频链接然后yt-dlp下载，直到没有下一页。/subscriptions?page=* 增加页数， 视频的链接都是在 /videos/\* 下  
