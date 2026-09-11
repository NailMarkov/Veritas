<#
  .SYNOPSIS
    Главный скрипт для мониторинга лог-файлов в директориях.

  .DESCRIPTION
    Выполняет начальную инициализацию системы, проверку наличия и размера лог-файлов в указанных папках.
    Запускает соответствующие скрипты обработки в зависимости от расположения файлов в папках.

    Блок begin (Инициализация):
    - Определяет рабочую директорию и преобразует относительные пути в абсолютные.
    - Подключает внешний модуль логирования (logger.ps1) и основной модуль функций (functions.psm1).
    - Загружает файл настроек (settings.json), проверяет его структуру и извлекает целевые папки.
    - Проверяет наличие файла лога за текущую дату. Если он существует, замеряет размер (Get-Size); если нет — создает новый (Start-Loging).
    - Выполняет валидацию доступности ключевых файлов конфигурации и модулей.

    Блок process (Основной функционал):
    - Выполняет последовательный обход всех папок, указанных в конфигурационном файле.
    - Проверяет физическое существование каждой папки. В случае отсутствия пишет ошибку в лог.
    - Сканирует содержимое папок (включая все вложенные поддиректории).
    - Подсчитывает общее количество файлов и вычисляет их суммарный размер в байтах и мегабайтах (МБ).
    - Фиксирует детальные результаты (или предупреждения для пустых директорий) в журнале событий.
    
  .NOTES
    Требования к окружению:
    - PowerShell версии 3.0 или выше.
    - Права на чтение файлов в проверяемых директориях.
    - Права на запись в директорию хранения логов скрипта.
    
    Ожидаемая структура зависимостей относительно корня скрипта:
    - Utils\ — содержит модуль logger.ps1
    - Modules\ — содержит модуль functions.psm1
    - Config\ — содержит файл настроек settings.json
#>

begin {
  # Получаем путь к папке, где запущен текущий скрипт
  $currentDir = $PSScriptRoot

  # Подключаем функцию логирования
  . .\Utils\Logger.ps1

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

        Write-Log -Message "Файлы найдены!" -Level "INFO"
        Write-Log -Message "Количество файлов: $fileCount" -Level "INFO"
        Write-Log -Message "Общий размер: $totalSizeMB МБ ($totalSizeByte байт)" -Level "INFO"

        switch -Wildcard ($folder) {
          "*Anyway*"  { & ".\Scripts\Find-$($config.scripts.anyway)Error.ps1" -Path $currentDir }
          "*Cashin*"  { & ".\Scripts\Find-$($config.scripts.cashin)Error.ps1" -Path $currentDir }
          "*Cashout*" { & ".\Scripts\Find-$($config.scripts.cashout)Error.ps1" -Path $currentDir }
          "*Other*"   { & ".\Scripts\Find-$($config.scripts.other)Error.ps1" -Path $currentDir }
          default     { Write-Log "Нет скрипта для $currentDir" -Level "WARNING" }
        }
      }
      else {
        Write-Log -Message "Папка пуста (файлов нет)." -Level "WARNING"
      }

    }
    else {
      Write-Log -Message "Папка не существует по указанному пути." -Level "ERROR"
    }
  }
}
