#!/usr/bin/env pwsh

param([string]$filter=$null)
 
function Test-Blockens {
    param (
        $TestPath
    )
    Write-Host "Testing $TestPath"
    zig test $TestPath
}

$tests = @(
    ".\src\game\block\lighting_ambient_edit.zig", 
    ".\src\game\block\lighting_ambient_fall.zig"
)

$tests_to_run = $tests
if ($filter -ne $null) {
    $tests_to_run = @($tests_to_run) -match $filter
}
foreach ($test in $tests_to_run) {
    Test-Blockens -TestPath $test
}

