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

    # Принимает абсолютно любой тип данных (объект общего вида)
    [Parameter(Mandatory = $false)]
    [object]$GenericData
  )

  process {
    try {
      # Поиск и перемещение файлов
      foreach ($extension in $GenericData.Keys) {
        $subFolder = $GenericData[$extension]
        $DestinationPath_1 = Join-Path -Path $DestinationPath -ChildPath $subFolder
    
        # Ищем файлы только в исходной папке (без подпапок)
        $FilesToMove = Get-ChildItem -Path $SourcePath -Filter "*.$extension" -File
    
        foreach ($File in $FilesToMove) {
          Move-Item -Path $File.FullName -Destination $DestinationPath_1 -Force
        }
        Write-Log -Message "Перемещение успешно завершено. Обработано файлов: $($filesToMove.Count)" -Level "INFO"
      }

    }
    catch {
      Write-Log -Message "Произошла ошибка при перемещении файлов: $_" -Level "ERROR"
    }
  }
}

# Экспортируем только нужные функции
Export-ModuleMember -Function @(
  'Move-Files'
)