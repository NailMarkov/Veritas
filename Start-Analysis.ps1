<#
  .SYNOPSIS
    Главный скрипт для мониторинга лог-файлов в директориях.

  .DESCRIPTION
    Выполняет начальную инициализацию системы, проверку наличия и размера лог-файлов в указанных папках.
    Запускает соответствующие скрипты обработки в зависимости от расположения файлов в папках.
    Фиксирует детальные результаты (INFO, WARNING, ERROR) в журнале событий.

    Блок begin (Инициализация):
    - Определяет рабочую директорию и преобразует относительные пути в абсолютные;
    - Подключает функцию логирования (logger.ps1) и основные модули (AnalysisTools.psm1 и FileSystemsTools.psm1);
    - Загружает файл настроек (settings.json);
    - Проверяет наличие файла логирования за текущую дату. Если файл логирования существует, замеряет размер (Get-Size) и
      если нет — создает новый (Start-Loging);
    - Выполняет валидацию доступности ключевых файлов конфигурации и модулей;

    Блок process (Основной функционал):
    - Выполняет последовательный обход всех папок, в которых могут присутсвовать файлы для обработки;
    - Подсчитывает общее количество файлов и вычисляет их суммарный размер в байтах и мегабайтах (МБ);
    - Выполняет запуск скрипта в зависимости от найденных файлов в папках;
    - Записывает информацию о файлах в формате CSV(Operations\Data\system_yyyy-mm-dd.csv); 
    
  .NOTES
    Требования к окружению:
    - PowerShell версии 3.0 или выше.
    - Права на чтение файлов в проверяемых директориях.
    - Права на запись в директорию хранения логов скрипта.
    
    Ожидаемая структура зависимостей относительно корня скрипта:
    - Utils\ — содержит скрипт logger.ps1
    - Modules\ — содержит модули AnalysisTools\AnalysisTools.psm1 и FileSystemsTools\FileSystemsTools.psm1
    - Config\ — содержит файл настроек settings.json
#>

begin {
  # Получаем путь к папке, где запущен текущий скрипт
  $currentDir = $PSScriptRoot

  # Подключаем дополнительные функции 
  $utilsFolders = Join-Path $currentDir "Utils"
  Get-ChildItem -Path $utilsFolders -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
  }

  # Загружаем настройки 
  $configPath = Join-Path $currentDir "Config\settings.json"
  $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

  # Загружаем модуль
  $modulePath = Join-Path $currentDir "$($config.directories.modules.analysis)\AnalysisTools.psm1"
  Import-Module $modulePath -Force

  # Проверяем наличие лог файла и его размер
  $loggerPath = Join-Path $currentDir $config.directories.logs
  $logFile = Join-Path $loggerPath "\log_$(Get-Date -Format 'dd-MM-yyyy').log"

  if (Test-Path $logFile -PathType Leaf) {
    Write-Log -Message "Обнаружен файл логирования: $logFile" -Level "INFO"
    Write-Log -Message "Проверяю объем файла..." -Level "INFO"
    Get-Size -File $logFile
  }
  else {
    Start-Loging -LogPath $loggerPath
  }

  # Проверяем подключение конфигурации
  if (Test-Path $configPath -PathType Leaf) {
    Write-Log -Message "Подключен файл конфигурации: $configPath" -Level "INFO"
  }
  else {
    Write-Log -Message "Файл конфигурации не найден: $configPath" -Level "ERROR"
  }

  # Проверяем подключение модуля
  if (Test-Path $modulePath -PathType Leaf) {
    Write-Log -Message "Подключен основной модуль: $modulePath" -Level "INFO"
  }
  else {
    Write-Log -Message "Основной модуль не найден: $modulePath" -Level "ERROR"
  }

  Write-Log -Message "Создаю массив папок с логами..." -Level "INFO"
  
  # Список папок для проверки
  $folders = foreach ($prop in $config.directories.logfiles.PSObject.Properties) {
    $relativePath = $prop.Value.TrimStart('\')
    Join-Path -Path $currentDir -ChildPath $relativePath
  }
  Write-Log -Message "Массив папок с логами создан" -Level "INFO"
}

process {
  Write-Log -Message "Проверяю папки на наличие файлов..." -Level "INFO"
  foreach ($folder in $folders) {
    Write-Log -Message "Проверка папки: $folder" -Level "INFO"

    # Проверяем, существует ли папка вообще
    if (Test-Path -Path $folder -PathType Container) {
        
      # Получаем все файлы внутри папки (включая подпапки)
      $files = Get-ChildItem -Path $folder -File -Recurse -ErrorAction SilentlyContinue

      if ($files) {
        # Считаем количество файлов
        $fileCount = $files.Count
            
        # Считаем суммарный размер в байтах и переводим в Мегабайты (МБ)
        $totalSizeByte = ($files | Measure-Object -Property Length -Sum).Sum
        $totalSizeMB = [Math]::Round($totalSizeByte / 1MB, 2)

        Write-Log -Message "Количество найденых файлов: $fileCount" -Level "INFO"

        switch -Wildcard ($folder) {
          "*Anyway*"  { & ".\Scripts\Find-$($config.scripts.anyway)Error.ps1" -Path $currentDir }
          "*Cashin*"  { & ".\Scripts\Find-$($config.scripts.cashin)Error.ps1" -Path $currentDir }
          "*Cashout*" { & ".\Scripts\Find-$($config.scripts.cashout)Error.ps1" -Path $currentDir }
          "*Other*"   { & ".\Scripts\Find-$($config.scripts.other)Error.ps1" -Path $currentDir }
          default     { Write-Log "Нет скрипта для $currentDir" -Level "WARNING" }
        }

        $totalFiles = [pscustomobject]@{
          time = $(Get-Date -Format 'dd-MM-yyyy HH:mm')
          log = Split-Path $folder -Leaf 
          count = $fileCount
          size = $totalSizeMB
        }
        Add-ToCsv -Data $totalFiles -Delimiter ";" -FileName "system" -Directory ".$($config.directories.operations.data)"
      }
      else {
        Write-Log -Message "Файлы не найдены" -Level "WARNING"
      }
    }
    else {
      Write-Log -Message "Папка не существует по указанному пути." -Level "ERROR"
    }
  }
}
