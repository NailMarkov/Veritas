<#
  .SYNOPSIS
  Блок begin
В этом блоке выполняется инициализация всех необходимых компонентов:

Определение рабочей директории

Путь к папке, где запущен текущий скрипт, сохраняется в переменную $currentDir

Подключение вспомогательных компонентов

Логирование: Подключается модуль logger.ps1 из папки Utils для ведения журнала событий

Конфигурация: Загружается JSON-файл настроек из Config\settings.json

Основной модуль: Импортируется модуль functions.psm1 из папки Modules с дополнительными функциями

Управление лог-файлом

Проверяется наличие лог-файла за текущую дату

Если файл существует — проверяется его размер с помощью функции Get-Size

Если файл отсутствует — запускается функция Start-Loging для создания нового файла

Валидация компонентов

Проверяется наличие и доступность:

Файла конфигурации

Основного модуля

В случае успеха/неудачи записываются соответствующие сообщения в лог
Формирование списка папок для проверки

Из конфигурационного файла извлекаются пути к директориям с лог-файлами

Пути преобразуются из относительных в абсолютные относительно корня скрипта

Блок process
В этом блоке выполняется основной функционал:

Обход папок с логами

Перебираются все папки, указанные в конфигурации

Проверка существования папки

Если папка существует — выполняется анализ

Если папка отсутствует — в лог записывается сообщение об ошибке

Анализ содержимого папки

Получаются все файлы внутри папки (включая вложенные подпапки)

Подсчитывается общее количество файлов

Вычисляется суммарный размер файлов в байтах и мегабайтах

Логирование результатов

В лог записывается:

Количество найденных файлов

Общий размер файлов в МБ и байтах

Если папка пуста — записывается предупреждение

Примечание о расширении функционала
В текущей версии скрипта реализован только сбор информации о лог-файлах. Однако архитектура скрипта предусматривает возможность расширения в блоке process для запуска определенных скриптов в зависимости от:

Пути к папке, в которой находятся файлы

Типа файлов (расширение, маска имени)

Размера или количества файлов

Даты создания/изменения файлов

Требования
PowerShell версии 3.0 или выше

Наличие следующих директорий относительно корня скрипта:

Utils\ — содержит модуль logger.ps1

Modules\ — содержит модуль functions.psm1

Config\ — содержит файл настроек settings.json с секцией directories.logfiles

Права на чтение файлов в проверяемых директориях

Права на запись в директорию логов

#>

begin {
  # Получаем путь к папке, где запущен текущий скрипт
  $currentDir = $PSScriptRoot

  # Подключаем функцию логирования
  . .\Utils\logger.ps1

  # Загружаем настройки 
  $configPath = Join-Path $currentDir "Config\settings.json"
  $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

  # Загружаем модуль
  $modulePath = Join-Path $currentDir "Modules\functions.psm1"
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
  # Список папок для проверки (укажите свои пути)
  $folders = foreach ($prop in $config.directories.logfiles.PSObject.Properties) {
    $relativePath = $prop.Value.TrimStart('\')
    Join-Path -Path $currentDir -ChildPath $relativePath
  }
}

process {
  Write-Log -Message "Массив папок с логами создан" -Level "INFO"

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
