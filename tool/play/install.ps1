# 한 번만 돌리면 된다: 플레이용 복제본을 만들고 바탕화면에 "Ashborn" 바로가기를 둔다.
#
#   powershell -ExecutionPolicy Bypass -File tool\play\install.ps1
#
# 복제본은 개발용 저장소 옆 (예: D:\project\ashborn-play) 에 두고 main 만 따라간다.
# 개발하면서 브랜치를 바꿔도 게임 쪽은 영향이 없다.

param([string]$Target)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $Target) { $Target = Join-Path (Split-Path $Repo -Parent) 'ashborn-play' }

if (Test-Path (Join-Path $Target '.git')) {
    Write-Host "복제본이 이미 있습니다: $Target"
} else {
    $origin = git -C $Repo remote get-url origin
    git clone --branch main $origin $Target
    if ($LASTEXITCODE -ne 0) { throw '복제에 실패했습니다.' }
}

$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Ashborn.lnk'))
$link.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$link.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Target\tool\play\play.ps1`""
$link.WorkingDirectory = $Target
$link.IconLocation = "$Target\tool\play\ashborn.ico"
$link.Description = 'Ashborn (최신 main)'
$link.Save()
Write-Host '바탕화면에 Ashborn 바로가기를 만들었습니다.'
