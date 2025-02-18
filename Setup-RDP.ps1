# Включаем службу Windows Remote Management (WinRM) для удаленных подключений
try {
    Enable-PSRemoting -Force
    Set-Service -Name WinRM -StartupType Automatic
    Start-Service -Name WinRM
    Write-Host "WinRM настроен успешно."
} catch {
    Write-Host "Ошибка при настройке WinRM: $_"
}

# Устанавливаем роли для удаленного рабочего стола
try {
    Install-WindowsFeature RDS-RD-Server, RDS-Licensing -IncludeManagementTools
    Write-Host "Роли для удаленного рабочего стола установлены успешно."
} catch {
    Write-Host "Ошибка при установке ролей RDS: $_"
}

# Ждем завершения установки и системы
Start-Sleep -Seconds 60

# Настроим лицензирование через реестр
try {
    Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "LicensingMode" -Value 2
    Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "SpecifiedLicenseServerList" -Value "127.0.0.1"
    Write-Host "Лицензирование настроено."
} catch {
    Write-Host "Ошибка при настройке лицензирования: $_"
}

# Разрешаем множественные сессии под одной учетной записью
try {
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server" -Name "fSingleSessionPerUser" -Value 0
    Write-Host "Множественные сессии разрешены."
} catch {
    Write-Host "Ошибка при настройке множественных сессий: $_"
}

# Настройка блокировки количества подключений RDP
try {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "MaxInstanceCount" -Value 100
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
    Write-Host "Максимальное количество подключений настроено."
} catch {
    Write-Host "Ошибка при настройке RDP: $_"
}

# Функция генерации случайного пароля
function Generate-Password {
    param([int]$length = 12)
    $characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+'
    return -join (1..$length | ForEach-Object { $characters[(Get-Random -Minimum 0 -Maximum $characters.Length)] })
}

# Запрос количества пользователей с проверкой правильности ввода
do {
    $numberOfUsers = Read-Host "Введите количество создаваемых пользователей (число от 1 до 100)"
} while (-not ($numberOfUsers -match '^\d+$') -or [in
