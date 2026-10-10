<#
.SYNOPSIS
  Скрипт добавления данных в CSV-файл за текущий день.

.DESCRIPTION
  Создаёт CSV-файл с именем текущего дня, если его нет, создает и добавляет в него данные.

.PARAMETER Data
  Данные для добавления:
    - тип данных: PSCustomObject

.PARAMETER Directory
  Директория для хранения CSV-файлов. В зависимости от полученных данных:
    - При старте системы: .\data
    - При обработке лог файлов: .\Operations\Data

.PARAMETER FileName
  Префикс имени файла. Если не указан — только дата (YYYY-MM-DD.csv).
    - При старте системы: system_YYYY-MM-DD.csv
    - При обработке лог файлов: operations_YYYY-MM-DD.csv

.PARAMETER Columns
  Заголовки столбцов (массив). Добавляются только при создании нового файла.

.PARAMETER Delimiter
  Разделитель полей CSV. По умолчанию: ","
    - При старте системы: ";"
    - При обработке лог файлов: ";"

.PARAMETER DateFormat
  Формат даты для имени файла. По умолчанию: "yyyy-MM-dd".

.PARAMETER Encoding
  Кодировка файла. По умолчанию: UTF8.

.EXAMPLE
  .\Add-ToCsv.ps1 -Data "Иван;25;Москва" -Columns "name","age","city" -Delimiter ";"

.EXAMPLE
  .\Add-ToCsv.ps1 -Data @{ name="Иван"; age=25; city="Москва" }
#>

. .\Utils\Logger.ps1

# Преобразование входных данных в массив объектов (строк)
function ConvertTo-Rows {
  param(
    [object]$InputData,
    [string]$Delimiter
  )

  $rows = @()
  $headers = @()

  # Приводим к массиву
  $items = @($InputData)

  foreach ($item in $items) {
    if ($item -is [PSCustomObject]) {
      Write-Log -Message "Обрабатываю тип данных PSCustomObject..." -Level "INFO"

      if ($headers.Count -eq 0) {
        $headers = @($item.PSObject.Properties.Name)
      }
      $row = [ordered]@{}
      foreach ($h in $headers) {
        $prop = $item.PSObject.Properties[$h]
        $row[$h] = if ($prop) { $prop.Value } else { "" }
      }
      $rows += [PSCustomObject]$row
    }
    else {
      Write-Log -Message "Неподдерживаемый тип данных: $($item.GetType().FullName)" -Level "ERROR"
    }
  }

  return @{ Rows = $rows; Headers = $headers }
}

# Формирование пути к файлу с именем текущего дня 
function Get-TodayFilePath {
  param(
    [string]$Directory,
    [string]$Prefix,
    [string]$DateFormat
  )

  $today = (Get-Date).ToString($DateFormat)
  $name = if ([string]::IsNullOrWhiteSpace($Prefix)) { "$today.csv" } else { "${Prefix}_$today.csv" }
  return Join-Path -Path $Directory -ChildPath $name
}

# Основная логика

function Add-ToCsv {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Data,
    [string]$Directory = ".\data",
    [string]$FileName = "",
    [string]$Delimiter = ",",
    [string]$DateFormat = "yyyy-MM-dd",
    [string]$Encoding = "UTF8"
  )
  try {
    $parsed = ConvertTo-Rows -InputData $Data -Delimiter $Delimiter
    $rows = $parsed.Rows
    $objectHeaders = $parsed.Headers

    if ($rows.Count -eq 0) {
      Write-Log -Message "Нет данных для записи." -Level "WARNING"
    }

    # Определяем заголовки
    $finalHeaders = @()
    if ($objectHeaders.Count -gt 0) {
      $finalHeaders = $objectHeaders
    }

    # Формируем путь к файлу
    $filePath = Get-TodayFilePath -Directory $Directory -Prefix $FileName -DateFormat $DateFormat

    # Создаём директорию
    if (-not (Test-Path -Path $Directory)) {
      New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    }

    # Проверка существования файла за текущий день
    $fileExists = Test-Path -Path $filePath
    $isNew = -not $fileExists

    # Если файл новый — записываем заголовок
    if ($isNew -and $finalHeaders.Count -gt 0) {
      $headerLine = ($finalHeaders | ForEach-Object {
          $h = $_.ToString()
          if ($h -match "[$]([regex]::Escape($Delimiter))`"`n\r]" ) { "`"$($h -replace '"','""')`"" } else { $h }
        }) -join $Delimiter
      $headerLine | Out-File -FilePath $filePath -Encoding $Encoding -NoNewline
      "`n" | Out-File -FilePath $filePath -Encoding $Encoding -Append -NoNewline
    }

    # Формируем строки CSV
    $lines = @()
    foreach ($row in $rows) {
      if ($row -is [PSCustomObject]) {
        $values = foreach ($h in $finalHeaders) {
          $val = $row.$h
          if ($null -eq $val) { "" } else { $val.ToString() }
        }
      }
      else {
        # Массив значений
        $values = $row
      }

      # Проверка количества столбцов
      if ($finalHeaders.Count -gt 0 -and $values.Count -ne $finalHeaders.Count) {
        Write-Log -Message "Строка содержит $($values.Count) значений, а заголовков — $($finalHeaders.Count)" -Level "ERROR"
      }

      # Экранирование значений
      $escaped = $values | ForEach-Object {
        $v = if ($null -eq $_) { "" } else { $_.ToString() }
        if ($v -match "[$]([regex]::Escape($Delimiter))`"`n\r]") {
          '"' + ($v -replace '"', '""') + '"'
        }
        else {
          $v
        }
      }
      $lines += ($escaped -join $Delimiter)
    }

    # Дописываем данные
    if ($lines.Count -gt 0) {
      $content = ($lines -join "`r`n") + "`r`n"
      Add-Content -Path $filePath -Value $content -Encoding $Encoding -NoNewline
    }

    $status = if ($isNew) { "создан" } else { "дополнен" }
    Write-Log -Message "Файл $filePath $status. Добавлено строк: $($rows.Count)" -Level "INFO"
  }
  catch {
    Write-Log -Message "Ошибка: $($_.Exception.Message)" -Level "ERROR"
  }
}