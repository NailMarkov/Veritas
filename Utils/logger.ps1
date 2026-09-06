# ============================================
# Основная функция логирования
# ============================================

function Write-Log {
  param(
    [string]$Message,
    [string]$Level = "INFO",
    [string]$LogFile = "Logs\log_$(Get-Date -Format 'dd-MM-yyyy').log"
  )
    
  # Формируем временную метку
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    
  # Формируем строку
  $logLine = "[$timestamp] [$Level] $Message"
    
  # Запись в файл
  $logLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
}