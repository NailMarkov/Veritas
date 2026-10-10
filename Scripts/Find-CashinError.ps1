
$currentDir = $PSScriptRoot
function Copy-Files {
  param(
    [string]$Path,
    [string]$PathFrom,
    [string]$PathWhere
  )
  Write-Host $Path
}

Copy-Files -Path $currentDir