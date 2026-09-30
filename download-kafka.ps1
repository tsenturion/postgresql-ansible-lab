param(
    [string]$Version = '4.3.1',
    [string]$ScalaVersion = '2.13',
    [string]$Mirror = 'https://mirror.yandex.ru/mirrors/apache/kafka',
    [string]$DestinationDirectory = (Join-Path $env:USERPROFILE 'Downloads')
)

$ErrorActionPreference = 'Stop'
$archiveName = "kafka_$ScalaVersion-$Version.tgz"
$archiveUrl = "$($Mirror.TrimEnd('/'))/$Version/$archiveName"
$destinationPath = Join-Path $DestinationDirectory $archiveName
New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
Write-Host "Скачивание готовой Kafka: $archiveUrl"
& curl.exe --fail --location --retry 3 --continue-at - --output $destinationPath $archiveUrl
if ($LASTEXITCODE -ne 0) {
    throw "Ошибка скачивания Kafka. Код curl: $LASTEXITCODE"
}
Write-Host "Архив сохранён: $destinationPath"
