#!/usr/bin/env pwsh

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

foreach ($test in $tests) {
    Test-Blockens -TestPath $test
}

