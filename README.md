# 通过powershell下载iwara(R18)视频

## 使用方法  

+ 本分支使用`Start-BitsTransfer`下载，也可以换成`Invoke-Webrequest`,不用额外装下载器
+ 支持从单个视频，用户，订阅里下载，不支持观看列表下载
+ `powershell -File *.ps1 -cookies cookie -uri URL -output output Dic`  
直接在脚本里设置变量也可，output就是输出的文件夹,useragent直接在脚本里设置，反正也不改
+ cookie和useragent从浏览器直接复制即可  
+ 下载到作者名字文件夹下 `output\username\video`
+ 最好别和yt-dlp混用，因为下载的文件名不一样，到时候一堆重复的
+ 下载订阅有个功能还没测试，理论上是每次下载后记录下时间，比这个早的直接跳过
