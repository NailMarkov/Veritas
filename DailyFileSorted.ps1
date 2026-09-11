begin {
  # Получаем путь к папке, где запущен текущий скрипт
  $currentDir = $PSScriptRoot

  # Подключаем функцию логирования
  . .\Utils\Logger.ps1

  # Загружаем настройки 
  $configPath = Join-Path $currentDir "Config\settings.json"
  $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

  # Создаем папку с текущей датой
  $CurrentDate = Get-Date -Format "yyyy-MM-dd"
  $PathArchive = Join-Path -Path $currentDir $($config.directories.operations.archive)
  $TodayMainFolder = Join-Path -Path $PathArchive -ChildPath $CurrentDate

  # Список расширений и папок для них
  $ExtensionsMap = @{
    "prj"    = "PrjFiles"
    "ndc"    = "NdcFiles"
    "ejdata" = "EjdataFiles"
  }
}

process {
  # Создаем главную папку дня и подпапки в ней
  foreach ($SubFolder in $ExtensionsMap.Values) {
    $PathToCreate = Join-Path -Path $TodayMainFolder -ChildPath $SubFolder
    if (-not (Test-Path -Path $PathToCreate)) {
      New-Item -Path $PathToCreate -ItemType Directory -Force | Out-Null
    }
  }

  # Поиск и перемещение файлов
  foreach ($Extension in $ExtensionsMap.Keys) {
    $SubFolder = $ExtensionsMap[$Extension]
    $DestinationPath = Join-Path -Path $TodayMainFolder -ChildPath $SubFolder
    
    # Ищем файлы только в исходной папке (без подпапок)
    $FilesToMove = Get-ChildItem -Path $SourceFolder -Filter "*.$Extension" -File
    
    foreach ($File in $FilesToMove) {
      Move-Item -Path $File.FullName -Destination $DestinationPath -Force
    }
  }
}