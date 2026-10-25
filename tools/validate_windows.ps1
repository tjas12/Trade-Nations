param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [switch]$Graphical
)
$ErrorActionPreference = 'Stop'
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
$projectPath = Split-Path -Parent $PSScriptRoot
$validationPath = Join-Path $projectPath '.validation'
$priorAppData = $env:APPDATA
$priorLocalAppData = $env:LOCALAPPDATA
New-Item -ItemType Directory -Force "$validationPath/roaming", "$validationPath/local" | Out-Null
$env:APPDATA = "$validationPath/roaming"
$env:LOCALAPPDATA = "$validationPath/local"
function Invoke-Validation([string]$Name, [string[]]$EngineArgs) {
    $logPath = Join-Path $validationPath "$Name.log"
    & $enginePath @EngineArgs *> $logPath
    $engineExit = $LASTEXITCODE
    $errorsFound = @(Get-Content -LiteralPath $logPath | Where-Object {
        ($_ -match 'SCRIPT ERROR:|^ERROR:|\] FAIL:') -and
        ($_ -notmatch '^ERROR: Failed to read the root certificate store\.$') -and
        ($_ -notmatch '^ERROR: [0-9]+ resources still in use at exit')
    })
    if ($engineExit -ne 0 -or $errorsFound.Count -gt 0) {
        Get-Content -LiteralPath $logPath -Tail 60
        throw "$Name failed (engine exit $engineExit); inspect $logPath"
    }
    Write-Output "PASS $Name -- $logPath"
    if (Select-String -LiteralPath $logPath -Pattern 'resources still in use') {
        Write-Output 'KNOWN DIAGNOSTIC: resources remain in use at shutdown; inspect the retained log.'
    }
}
try {
    Invoke-Validation 'import' @('--headless', '--editor', '--path', $projectPath, '--import', '--quit')
    Invoke-Validation 'foundation' @('--headless', '--path', $projectPath, 'res://tests/TestRunner.tscn')
    Invoke-Validation 'restoration' @('--headless', '--path', $projectPath, 'res://tests/RestorationTests.tscn')
    Invoke-Validation 'interaction' @('--headless', '--path', $projectPath, 'res://tests/InteractionTests.tscn')
    Invoke-Validation 'playable' @('--headless', '--path', $projectPath, 'res://tests/PlayableTests.tscn')
    Invoke-Validation 'scale' @('--headless', '--path', $projectPath, 'res://tests/ScaleTests.tscn')
    Invoke-Validation 'layout' @('--headless', '--path', $projectPath, 'res://tests/LayoutTests.tscn')
    Invoke-Validation 'main' @('--headless', '--path', $projectPath, '--quit-after', '120')
    if ($Graphical) {
        Invoke-Validation 'playable-forward-plus' @('--path', $projectPath, 'res://tests/PlayableTests.tscn')
        Invoke-Validation 'layout-forward-plus' @('--path', $projectPath, 'res://tests/LayoutTests.tscn')
        Invoke-Validation 'graphical' @('--path', $projectPath, '--rendering-method', 'gl_compatibility', 'res://tests/RestorationTests.tscn')
        Invoke-Validation 'interaction-forward-plus' @('--path', $projectPath, 'res://tests/InteractionTests.tscn')
    }
} finally {
    $env:APPDATA = $priorAppData
    $env:LOCALAPPDATA = $priorLocalAppData
}
