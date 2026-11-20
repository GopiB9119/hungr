# Runs the Firestore + Storage security-rules tests on the local emulators.
# Uses the demo project, so nothing touches the real Hungr Firebase project.
param([switch]$KeepLog)

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$log = Join-Path $env:TEMP 'hungr-rules-test.log'
Push-Location $repo
try {
  firebase emulators:exec --only "firestore,storage" --project demo-hungr "node --test qa/rules-test/" 2>&1 |
    Tee-Object -FilePath $log | Where-Object { $_ -match '\(\d+(\.\d+)?ms\)$|^\S+ (tests|pass|fail) \d+$' }
  $failed = -not (Select-String -Path $log -Pattern '^\S+ fail 0$' -Quiet)
} finally {
  # With newer Java the Firestore emulator can outlive emulators:exec. Stop only our demo emulator.
  Start-Sleep -Seconds 2
  Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
    Where-Object { $_.CommandLine -match 'cloud-firestore-emulator' -and $_.CommandLine -match 'demo-hungr' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
  Remove-Item (Join-Path $repo 'firestore-debug.log'), (Join-Path $repo 'firebase-debug.log') -ErrorAction SilentlyContinue
  Pop-Location
}
if (-not $KeepLog) { Remove-Item $log -ErrorAction SilentlyContinue }
if ($failed) { Write-Error 'Rules tests failed.'; exit 1 }
'Rules tests passed.'
