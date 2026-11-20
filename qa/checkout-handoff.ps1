[CmdletBinding()]
param([switch]$Verify)

$ErrorActionPreference = 'Stop'
$file = Join-Path $PSScriptRoot 'checkout-decisions.json'
$decisions = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($decisions).Count -eq 0 -or $null -eq $decisions) { throw 'The checkout decision list is empty.' }

Write-Output 'Hungr checkout handoff - local QA only. Customer checkout stays disabled.'
$pending = 0
foreach ($entry in $decisions) {
    if ($entry.question -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.question) -or
        $entry.PSObject.Properties.Name -notcontains 'answer') { throw 'Invalid checkout decision entry.' }
    if ($null -eq $entry.answer) {
        $pending++
        Write-Output ("OPEN: {0}" -f $entry.question)
    } elseif ($entry.answer -is [string] -and -not [string]::IsNullOrWhiteSpace($entry.answer)) {
        Write-Output ("ANSWERED: {0}`n  {1}" -f $entry.question, $entry.answer)
    } else {
        throw 'A decision answer must be null (open) or a short approved business decision.'
    }
}
if ($pending -gt 0) {
    Write-Output 'Next: continue offline tests. Record confirmed business decisions only; do not guess.'
} else {
    Write-Output 'Next: review the decisions and implement the staging integration. This is not launch approval.'
}
if ($Verify) {
    Push-Location (Join-Path $PSScriptRoot '..\functions')
    try {
        & node --test
        if ($LASTEXITCODE -ne 0) { throw "Functions tests failed (exit $LASTEXITCODE)." }
    } finally {
        Pop-Location
    }
}
