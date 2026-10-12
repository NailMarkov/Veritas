<#
  .SYNOPSIS
    Скрипт перемещения файлов.

  .DESCRIPTION
    Создает папку с текущей датой в директории Operations\Archive\YYYY-MM-DD.
    Создает подпапки в созданной папке(\EjdataFiles, \NdcFiles, \PrjFiles).
    Фиксирует детальные результаты (INFO, WARNING, ERROR) в журнале событий.

    Блок begin (Инициализация):
    - Определяет рабочую директорию и преобразует относительные пути в абсолютные;
    - Подключает функцию логирования (logger.ps1);
    - Загружает файл настроек (settings.json);
    - Создает папку с текущей датой(YYYY-MM-DD);
    - Создает объект с названием подпапок($extensionsMap);

    Блок process (Основной функционал):
    - Выполняет создание подпапок в папке текущего дня;
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
  $modulePath = Join-Path $currentDir "$($config.directories.modules.filesystems)\FileSystemsTools.psm1"
  Import-Module $modulePath -Force

  # Создаем структуру папок
  $year = (Get-Date).Year

  # Список месяцев
  $months = @(
    "Январь","Февраль","Март","Апрель","Май","Июнь",
    "Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"
  )

  $monthNum = (Get-Date).Month
  $folderMonth = $months[$monthNum - 1]

  # Создаем папку с текущей датой
  $currentDate = Get-Date -Format "yyyy-MM-dd"
  $dayFolder = Join-Path -Path $currentDir "$($config.directories.operations.archive)\$folderMonth"
  $todayMainFolder = Join-Path -Path $dayFolder -ChildPath $currentDate

  $sourceFile = Join-Path -Path $currentDir "$($config.directories.operations.files)"

  # Список расширений и папок для них
  $extensionsMap = @{
    "prj"    = "PrjFiles"
    "ndc"    = "NdcFiles"
    "ejdata" = "EjdataFiles"
  } 
}

process {
  function Add-Folder {
    param (
      [string]$Folder
    )
    $pathFolder = Join-Path -Path $currentDir "$($config.directories.operations.archive)\$Folder"

    if (-not (Test-Path $pathFolder)) {
      New-Item -Path $pathFolder -ItemType Directory | Out-Null
      Write-log -Message "Создана папка: $pathFolder" -Level "INFO"
    } else {
      Write-log -Message "Папка уже существует: $pathFolder" -Level "WARNING"
    }
  }

  try {
    Add-Folder -Folder $folderMonth
    Add-Folder -Folder $year
      
    # Создаем подпапки в текущей папке дня
    foreach ($subFolder in $extensionsMap.Values) {
      $pathToCreate = Join-Path -Path $todayMainFolder -ChildPath $subFolder
      Write-log -Message "Создана папка для файлов: $subFolder" -Level "INFO"

      if (-not (Test-Path -Path $pathToCreate)) {
        New-Item -Path $pathToCreate -ItemType Directory -Force | Out-Null
      }
    }

    Move-Files -GenericData $extensionsMap -DestinationPath $todayMainFolder -SourcePath $sourceFile
  }
  catch {
    Write-Log -Message "Ошибка: $($_.Exception.Message)" -Level "ERROR"
  }
}