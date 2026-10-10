# Ashborn 을 이 PC 에서 최신 main 으로 실행한다.
#
# 개발용 저장소와 따로 둔 "플레이용 복제본" (install.ps1 이 만든다) 에서 돈다.
#   1. origin/main 을 받아 fast-forward 한다. 복제본에 손댄 흔적이 있으면 건드리지 않는다.
#   2. 지난번 빌드와 커밋이 다를 때만 웹으로 다시 빌드한다 (약 40초).
#   3. 127.0.0.1 에 띄우고 전용 Chrome 프로필의 앱 창으로 연다.
#
# 세이브는 전용 프로필 (%LOCALAPPDATA%\Ashborn\browser) 의 localStorage 에 남는다.
# 평소 Chrome 의 방문 기록 · 쿠키를 지워도 영향이 없다. 주소 (포트) 가 바뀌면 다른 세이브가 되므로 고정한다.

$Port = 8723
$Url = "http://127.0.0.1:$Port/"
$BrowserProfile = Join-Path $env:LOCALAPPDATA 'Ashborn\browser'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Web = Join-Path $Root 'build\web'
$Stamp = Join-Path $Web '.ashborn-commit'

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = 'Ashborn 실행기'
Set-Location $Root

function Fail($message) {
    Write-Host ''
    Write-Host $message -ForegroundColor Red
    Read-Host '엔터를 누르면 닫힙니다'
    exit 1
}

function Test-Port {
    $client = New-Object Net.Sockets.TcpClient
    try { $client.Connect('127.0.0.1', $Port); return $true }
    catch { return $false }
    finally { $client.Close() }
}

# 1. 최신 main 받기
Write-Host '최신 버전 확인 중...' -ForegroundColor Cyan
$branch = git rev-parse --abbrev-ref HEAD
# 빌드할 때 flutter pub get 이 플러그인 등록 파일을 다시 쓴다. 손댄 것이 아니니 되돌려 두고 본다.
# (예전에는 이 파일들의 줄바꿈 차이 때문에 "바뀐 파일" 로 잡혀 업데이트가 계속 막혔다.)
git checkout --quiet -- windows/flutter 2>$null
git fetch origin main --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host '  인터넷 연결이 없어 지금 받아 둔 버전으로 실행합니다.' -ForegroundColor Yellow
} elseif ($branch -ne 'main') {
    Write-Host "  지금 브랜치가 main 이 아니라 ($branch) 업데이트를 건너뜁니다." -ForegroundColor Yellow
} elseif ($dirty = git status --porcelain) {
    Write-Host '  플레이용 복제본에 바뀐 파일이 있어 업데이트를 건너뜁니다:' -ForegroundColor Yellow
    $dirty | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
} else {
    git merge --ff-only --quiet origin/main
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  main 을 fast-forward 할 수 없어 업데이트를 건너뜁니다.' -ForegroundColor Yellow
    }
}
$head = git rev-parse HEAD
Write-Host ("  버전: " + (git log -1 --format='%h %s' HEAD))

# 2. 바뀌었을 때만 빌드
$built = if (Test-Path $Stamp) { (Get-Content $Stamp -Raw).Trim() } else { '' }
if ($built -ne $head) {
    Write-Host '새 버전을 빌드하는 중... (약 40초)' -ForegroundColor Cyan
    # Windows 플러그인용 "개발자 모드를 켜라" 경고가 나오지만 웹 빌드와는 상관없어 숨긴다.
    flutter pub get *> $null
    flutter build web --release --no-web-resources-cdn
    if ($LASTEXITCODE -eq 0) {
        Set-Content -Path $Stamp -Value $head -Encoding ascii
    } elseif (Test-Path (Join-Path $Web 'index.html')) {
        Write-Host '  빌드에 실패해 이전 빌드로 실행합니다.' -ForegroundColor Yellow
    } else {
        Fail '빌드에 실패했습니다.'
    }
}

# 3. 서버 띄우기 (이미 떠 있으면 그대로 쓴다)
$server = $null
if (-not (Test-Port)) {
    $server = Start-Process python -ArgumentList '-I', "`"$PSScriptRoot\serve.py`"", "`"$Web`"", $Port `
        -WindowStyle Hidden -PassThru
    for ($i = 0; $i -lt 50 -and -not (Test-Port); $i++) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Port)) { Fail "서버를 띄우지 못했습니다 (포트 $Port)." }
}

# 4. 전용 프로필의 앱 창으로 열기
$browser = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { Fail 'Chrome 이나 Edge 를 찾지 못했습니다.' }

# 게임 창은 없는데 이 프로필의 브라우저 프로세스만 남아 있으면 세이브 저장소를 쥐고 있을 수 있다.
# 그러면 새 창이 저장소를 열지 못해 빈 기록으로 뜬다 (2026-10-10 에 실제로 겪었다). 남은 것을 정리한다.
$profileProcs = Get-CimInstance Win32_Process -Filter "Name='chrome.exe' OR Name='msedge.exe'" |
    Where-Object { $_.CommandLine -like "*$BrowserProfile*" }
if ($profileProcs) {
    $visible = $profileProcs | Where-Object {
        (Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue).MainWindowHandle -ne 0
    }
    if (-not $visible) {
        Write-Host '  지난번 게임 브라우저가 덜 꺼져 있어 정리합니다.' -ForegroundColor Yellow
        $profileProcs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Milliseconds 500
    }
}

# 세이브 백업: 실행할 때마다 세이브 저장소를 통째로 복사해 둔다 (최근 20개).
# 저장소가 열리지 않아 빈 기록으로 뜨더라도 여기서 되살릴 수 있다.
$Storage = Join-Path $BrowserProfile 'Default\Local Storage'
$Backups = Join-Path $env:LOCALAPPDATA 'Ashborn\save-backups'
if (Test-Path $Storage) {
    Copy-Item $Storage (Join-Path $Backups (Get-Date -Format 'yyyyMMdd-HHmmss')) -Recurse -ErrorAction SilentlyContinue
    Get-ChildItem $Backups -Directory | Sort-Object Name -Descending | Select-Object -Skip 20 |
        Remove-Item -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Host '게임을 엽니다. 게임 창을 닫으면 이 창도 닫힙니다.' -ForegroundColor Green
$window = Start-Process $browser -PassThru -ArgumentList @(
    "--app=$Url",
    "--user-data-dir=`"$BrowserProfile`"",
    '--window-size=440,900',
    '--no-first-run',
    '--no-default-browser-check'
)
$window.WaitForExit()

if ($server) { Stop-Process -Id $server.Id -ErrorAction SilentlyContinue }
