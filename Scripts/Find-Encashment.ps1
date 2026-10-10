# $start = Select-String -Path "D:\powershell\Veritas\LogFiles\Other_Error\20261007.PRJ" -Pattern "О Т К Р Ы Т И Е   С Е С С И И     B R M " -Encoding Windows-1251
# Write-Host $start.LineNumber

$file = "D:\powershell\Veritas\LogFiles\Other_Error\20261007.PRJ"
$marker = "ОПЕРАЦИИ ПО ВЫДАЧЕ НАЛИЧНЫХ:"
$results = @()

Select-String -Path $file -Pattern $marker -Encoding Windows-1251 |
ForEach-Object {
  $block = $_.Context.PostContext   # строки после
  $obj = [ordered]@{ Line = $_.LineNumber }

  $obj.Date = if ($_.Line -match "ВРЕМЯ ОТКРЫТИЯ ОД:") { $Matches[2] }
  $obj.Time = if ($_.Line -match "СОСТОЯНИЕ ОД:") { $Matches[3] }

  foreach ($l in $block) {
    if ($l -match "ВЫДАНО           :") { $obj.Id = $Matches[3] }
    # if ($l -match "Имя:\s*(.+)") { $obj.Name = $Matches[1].Trim() }
  }

  $results += [pscustomobject]$obj
}

$results | Format-Table -AutoSize