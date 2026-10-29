<#
.SYNOPSIS
  One-click release build script for TinigSenyas Android APK.
.DESCRIPTION
  Builds the release APK optimized for Google Drive distribution and opens
  the destination folder in Windows Explorer.
#>

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  TinigSenyas: Building Android Release   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "`n[1/3] Getting latest Flutter dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n[2/3] Compiling Release APK..." -ForegroundColor Yellow
flutter build apk --release

$outputDir = Join-Path $scriptDir "build\app\outputs\flutter-apk"
$apkFile = Join-Path $outputDir "app-release.apk"

if (Test-Path $apkFile) {
    Write-Host "`n[3/3] Build Successful!" -ForegroundColor Green
    Write-Host "APK Location: $apkFile" -ForegroundColor Green
    Write-Host "`nOpening output folder in Explorer... Drag 'app-release.apk' to your Google Drive!" -ForegroundColor Cyan
    explorer.exe /select,$apkFile
} else {
    Write-Host "`nBuild completed, but APK not found at expected path: $apkFile" -ForegroundColor Red
}

