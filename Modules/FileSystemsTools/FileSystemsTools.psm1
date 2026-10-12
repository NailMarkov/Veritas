# Экспортируемые функции

# Подключаем функцию логирования
. .\Utils\Logger.ps1

function Move-Files {
  [CmdletBinding()]
  param (
    # Путь, КУДА перемещать файлы
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$DestinationPath,

    # Путь, ОТКУДА перемещать файлы
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$SourcePath,

    # Фильтр файлов (например, '*.txt' или @('*.jpg', '*.png'))
    [Parameter(Mandatory = $false)]
    [string[]]$FileFilter = "*",

    # Переключатель: искать ли файлы в поддиректориях source
    [Parameter(Mandatory = $false)]
    [switch]$Recurse,

    # Переключатель: перезаписывать ли файлы в целевой папке, если они уже существуют
    [Parameter(Mandatory = $false)]
    [switch]$Force,

    # Принимает абсолютно любой тип данных (объект общего вида)
    [Parameter(Mandatory = $false)]
    [object]$GenericData
  )

  process {
    try {
      # # Проверяем существование исходной директории
      # if (-not (Test-Path -Path $SourcePath -PathType Container)) {
      #   throw "Исходная директория '$SourcePath' не найдена."
      # }

      # # Создаем целевую директорию, если её нет
      # if (-not (Test-Path -Path $DestinationPath -PathType Container)) {
      #   Write-Verbose "Создание целевой директории: $DestinationPath"
      #   New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
      # }

      # # Настройки поиска файлов (с подпапками или без)
      # $searchOptions = @{
      #   Path   = $SourcePath
      #   File   = $true
      #   Filter = $null
      # }
      # if ($Recurse) { $searchOptions.Recurse = $true }

      # # Получаем список файлов по фильтрам
      # $filesToMove = Get-ChildItem @searchOptions | Where-Object {
      #   $file = $_
      #   # Проверка на соответствие коллекции фильтров (wildcards)
      #   $matches = $false
      #   foreach ($mask in $FileFilter) {
      #     if ($file.Name -like $mask) { $matches = $true; break }
      #   }
      #   $matches
      # }

      # if ($filesToMove.Count -eq 0) {
      #   Write-Warning "Файлы для перемещения не найдены."
      #   return
      # }

      # Поиск и перемещение файлов
      foreach ($extension in $GenericData.Keys) {
        $subFolder = $GenericData[$extension]
        $DestinationPath_1 = Join-Path -Path $DestinationPath -ChildPath $subFolder
    
        # Ищем файлы только в исходной папке (без подпапок)
        $FilesToMove = Get-ChildItem -Path $SourcePath -Filter "*.$extension" -File
    
        foreach ($File in $FilesToMove) {
          Move-Item -Path $File.FullName -Destination $DestinationPath_1 -Force
        }
      }

      Write-Host "Перемещение успешно завершено. Обработано файлов: $($filesToMove.Length)" -ForegroundColor Green
    }
    catch {
      Write-Error "Произошла ошибка при перемещении файлов: $_"
    }
  }
}

# Экспортируем только нужные функции
Export-ModuleMember -Function @(
  'Move-Files'
)