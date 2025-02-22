# Проверка, запущен ли скрипт от имени администратора
$CurrentUser = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $CurrentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "⛔ Скрипт необходимо запустить от имени администратора!" -ForegroundColor Red
    Exit
}

# Запрос количества пользователей
$UserCount = Read-Host "Введите количество пользователей для создания"

# Функция генерации пароля
function Generate-Password {
    param ([int]$length = 12)
    $Chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()'
    return -join (Get-Random -Count $length -InputObject $Chars.ToCharArray())
}

# Массив для хранения пользователей и их паролей
$UsersList = @()

# Создание пользователей
for ($i = 1; $i -le $UserCount; $i++) {
    $Username = "User$i"
    $Password = Generate-Password

    try {
        # Создание пользователя
        New-LocalUser -Name $Username -Password (ConvertTo-SecureString -String $Password -AsPlainText -Force) -FullName $Username -Description "RDP User" -ErrorAction Stop

        # Добавление пользователя в группу "Remote Desktop Users"
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction Stop

        Write-Host "✅ Пользователь $Username создан."

        # Добавление пользователя и пароля в список
        $UsersList += "$Username : $Password"

    }
    catch {
        Write-Host "❌ Ошибка при создании пользователя $Username. $_"
    }
}

# Сохранение списка пользователей и паролей на рабочий стол
$UsersFile = "$env:USERPROFILE\Desktop\RDP_Users.txt"
$UsersList | Out-File -Encoding UTF8 -FilePath $UsersFile
Write-Host "✅ Список пользователей и паролей сохранён в $UsersFile"

# Настройка реестра для RDP
$RdpRegPath = "HKLM:\System\CurrentControlSet\Control\Terminal Server"
$LicensingRegPath = "HKLM:\System\CurrentControlSet\Control\Terminal Server\Licensing Core"

# Проверка существования путей реестра перед изменением
if (Test-Path $RdpRegPath) {
    Set-ItemProperty -Path $RdpRegPath -Name "fDenyTSConnections" -Value 0
    Write-Host "🔹 Разрешены RDP-подключения."
} else {
    Write-Host "⚠ Путь $RdpRegPath не найден!"
}

if (Test-Path $LicensingRegPath) {
    Set-ItemProperty -Path $LicensingRegPath -Name "EnableConcurrentSessions" -Value 1
    Write-Host "🔹 Снято ограничение на число одновременных RDP-подключений."
} else {
    Write-Host "⚠ Путь $LicensingRegPath не найден!"
}

# Отключение проверки терминальных лицензий
$GracePeriodPath = "HKLM:\System\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod"

if (Test-Path $GracePeriodPath) {
    try {
        Remove-Item -Path "$GracePeriodPath\*" -Force -ErrorAction Stop
        Write-Host "✅ Удалён ключ GracePeriod для обхода проверки лицензий RDS." -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Ошибка при удалении GracePeriod: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ Путь $GracePeriodPath не найден!" -ForegroundColor Yellow
}

# Отключение проверки лицензий в реестре
$RdsPoliciesPath = "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services"

if (-not (Test-Path $RdsPoliciesPath)) {
    New-Item -Path $RdsPoliciesPath -Force | Out-Null
}

Set-ItemProperty -Path $RdsPoliciesPath -Name "LicenseServers" -Value ""
Set-ItemProperty -Path $RdsPoliciesPath -Name "EnableConcurrentSessions" -Value 1
Set-ItemProperty -Path $RdsPoliciesPath -Name "AllowMultipleTSSessions" -Value 1
Write-Host "🔹 Настроены параметры обхода лицензий RDS." -ForegroundColor Cyan

# Отключение NLA (по необходимости)
$NlaRegPath = "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"

if (Test-Path $NlaRegPath) {
    Set-ItemProperty -Path $NlaRegPath -Name "UserAuthentication" -Value 0
    Write-Host "🔹 Отключена проверка NLA (Network Level Authentication)." -ForegroundColor Cyan
} else {
    Write-Host "⚠ Путь $NlaRegPath не найден!" -ForegroundColor Yellow
}

Write-Host "🔹 Полная настройка RDP завершена." -ForegroundColor Cyan

# Запрос на перезагрузку
$Restart = Read-Host "Хотите перезагрузить сервер? (Y/N)"
if ($Restart -eq "Y") {
    Restart-Computer -Force
} else {
    Write-Host "⛔ Перезагрузка отменена." -ForegroundColor Red
}
