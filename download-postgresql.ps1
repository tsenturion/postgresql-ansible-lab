param(
    [string]$Url = 'https://mirror.yandex.ru/mirrors/postgresql/pool/main/p/postgresql-18/postgresql-18_18.6.orig.tar.bz2',
    [string]$Destination = (Join-Path $env:USERPROFILE 'Downloads')
)

$ErrorActionPreference = 'Stop'
$archiveName = [System.IO.Path]::GetFileName(([Uri]$Url).AbsolutePath)
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$archivePath = Join-Path $Destination $archiveName
Write-Host "Загрузка исходников PostgreSQL в $archivePath"
& curl.exe --ipv4 --fail --location --retry 3 --continue-at - --output $archivePath $Url
if ($LASTEXITCODE -ne 0) {
    throw 'Загрузка не завершена. Повторите запуск для продолжения с сохранённой позиции.'
}
Write-Host 'Передайте архив через FileZilla в /usr/local/src на ноде перед запуском Ansible.'
