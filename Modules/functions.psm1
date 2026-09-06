# Экспортируемые функции

# Подключаем функцию логирования
. .\Utils\logger.ps1

function Start-Loging {
  param(
    [string]$LogPath,
    [string]$File = "log_$(Get-Date -Format 'dd-MM-yyyy').log",
    [int]$Part = 1
  )

  $title = @(
    "===========================================",
    "=== Старт логирования: $((Get-Date).ToString('dd-MM-yyyy HH:mm')) ===",
    "=== Часть $Part                             ==="
    "==========================================="
  )
  $title | Set-Content $LogPath\$File -Encoding UTF8
}

function Find-Number {
  param(
    [string]$SearchToFile
  )

  $Line = (Get-Content "$SearchToFile")[2]
  $Number = (($Line -split " ")[2]).Trim()
  
  return [int]$Number + 1
}
function Get-Size {
  param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [int]$MaxSizeFile = 10 # 1 Мегабайт = 1024 Килобайта
  )
    
  # Получаем размер файла в КБ
  $LogFile = Get-Item -Path $File
  $CurrentSizeKB = $LogFile.Length / 1KB

  # Если размер больше 1024 КБ (1 MB) — архивируем
  if ($CurrentSizeKB -ge $MaxSizeFile) {
    
    $Number = Find-Number -SearchToFile $File

    $Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $ArchiveDir = $LogFile.DirectoryName
    $ArchiveName = "$($LogFile.BaseName)_$Timestamp.zip"
    $ArchiveFullPath = Join-Path -Path $ArchiveDir -ChildPath $ArchiveName

    try {
      Write-Log -Message "Размер лога превысил 1 MB ($([math]::Round($CurrentSizeKB, 1)) KB). Архивирую..." -Level "WARNING"

      # Сжатие и очистка
      Compress-Archive -Path $File -DestinationPath $ArchiveFullPath -Force -ErrorAction Stop
      Clear-Content -Path $File -ErrorAction Stop
            
      Write-Log -Message "Лог успешно заархивирован в: $ArchiveFullPath" -Level "INFO"
      Start-Loging -Part $Number -LogPath $(Split-Path $File)
    }
    catch {
      Write-Log -Message "Ошибка ротации лога: $_" -Level "ERROR"
    }
  }
  else {
    Write-Log -Message "Лог не привышает заданный размер - $MaxSizeFile" -Level "INFO"
  }
}

# Экспортируем только нужные функции
Export-ModuleMember -Function @(
  'Get-Size',
  'Start-Loging',
  'Find-Number'
)