Invoke-WebRequest "https://ghproxy.net/raw.githubusercontent.com/Magisk-Modules-Alt-Repo/json/main/modules.json" -OutFile modules-raw.json
$content = Get-Content modules-raw.json
$content `
    -replace "https://raw.githubusercontent.com/", "https://ghproxy.net/raw.githubusercontent.com/" `
    -replace "https://github.com/", "https://ghproxy.net/github.com/" `
| Set-Content modules.json