#!/usr/bin/env pwsh

param([string]$filter=$null)
 
$exit_code = 0

function Test-Blockens {
    param (
        $TestPath
    )
    Write-Host "Testing $TestPath"
   
    Set-Variable  -Name "passed" -Value $false
    zig test $TestPath && Set-Variable  -Name "passed" -Value $true
   
    return Get-Variable -Name "passed" -ValueOnly
}

$tests = @(
    ".\src\game\block\lighting_ambient_edit.zig", 
    ".\src\game\block\lighting_ambient_fall.zig",
    ".\src\game\block\block.zig",
    ".\src\game\block\chunk_terrain_descriptor.zig",
    ".\src\game\block\chunk_compress.zig",
    ".\src\game\block\chunk_sub_chunker.zig",
    ".\src\game\block\chunk_sub_chunk.zig",
    ".\src\game\ui\ui_format.zig"
)

$tests_to_run = $tests
if ($filter -ne $null) {
    $tests_to_run = @($tests_to_run) -match $filter
}
foreach ($test in $tests_to_run) {
    $passed = Test-Blockens -TestPath $test 
    if ($passed -eq $false) {
        $exit_code = 1
    }
}

if ($exit_code -eq 1) {
    Write-Error "Tests failed"
    exit $exit_code
}
Write-Host "Tests succeeded"
exit $exit_code
