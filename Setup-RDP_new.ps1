# Устанавливаем Execution Policy на RemoteSigned
Set-ExecutionPolicy RemoteSigned -Force

# Проверяем права администратора
if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit")) {
    Write-Host "❌ Скрипт должен быть запущен от имени администратора!"
    exit
}

# Запрашиваем количество пользователей (проверка на ввод чисел)
do {
    $UserCount = Read-Host "Введите количество пользователей для создания"
    if ($UserCount -match '\D' -or [int]$UserCount -le 0) {
        Write-Host "❌ Ошибка: введите корректное положительное число."
    }
} while ($UserCount -match '\D' -or [int]$UserCount -le 0)

# Функция генерации случайного пароля (12 символов: буквы разного регистра + цифры)
function Generate-Password {
    $length = 12
    return [System.Web.Security.Membership]::GeneratePassword($length, 4)  # Генерация более сложных паролей
}

# Логирование ошибок
function Log-Error {
    param([string]$ErrorMessage)
    $logFile = "C:\RDP_Error_Log.txt"
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$timestamp - $ErrorMessage" | Out-File -Append -FilePath $logFile
}

# Создаём пользователей
$UsersList = @()
for ($i=1; $i -le $UserCount; $i++) {
    $Username = "User$i"
    
    # Проверка, существует ли пользователь
    if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
        Write-Host "⚠️ Пользователь $Username уже существует, пропускаем..."
        continue
    }

    $Password = Generate-Password
    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

    # Создаём пользователя
    try {
        New-LocalUser -Name $Username -Password $SecurePassword -FullName "User $i" -Description "RDP User" -ErrorAction Stop
        Write-Host "✅ Пользователь $Username успешно создан"
    } catch {
        Write-Host "❌ Ошибка при создании пользователя $Username"
        Log-Error "Ошибка при создании пользователя $Username"
        continue
    }

    # Добавляем пользователя в группу RDP
    try {
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction Stop
        Write-Host "✅ Пользователь $Username добавлен в группу Remote Desktop Users"
    } catch {
        Write-Host "❌ Ошибка при добавлении пользователя $Username в группу"
        Log-Error "Ошибка при добавлении $Username в группу Remote Desktop Users"
        continue
    }

    # Запоминаем логины и пароли
    $UsersList += "Логин: $Username | Пароль: $Password"
}

# Сохраняем в файл на рабочем столе
$DesktopPath = [System.Environment]::GetFolderPath('Desktop')
$FilePath = "$DesktopPath\RDP_Users.txt"
$UsersList | Out-File -FilePath $FilePath -Encoding utf8

Write-Host "✅ Список пользователей сохранён в $FilePath"

# Разрешаем несколько одновременных RDP-сессий
Write-Host "🔹 Снимаем ограничение на количество RDP-подключений..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fSingleSessionPerUser" -Value 0
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\Licensing Core" -Name "EnableConcurrentSessions" -Value 1
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\TermService" -Name "Start" -Value 2

# Увеличиваем число разрешённых одновременных подключений
Write-Host "🔹 Увеличиваем число разрешённых одновременных подключений..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxInstanceCount" -Value 999999
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanServer\Parameters" -Name "MaxMpxCt" -Value 65535
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanServer\Parameters" -Name "MaxWorkItems" -Value 8192

# Отключаем ограничение по времени неактивных сессий
Write-Host "🔹 Отключаем ограничение по времени неактивных RDP-сессий..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxIdleTime" -Value 0

# Проверка и перезапуск службы RDP
$serviceStatus = (Get-Service -Name TermService).Status
if ($serviceStatus -ne 'Running') {
    Write-Host "🔹 Служба не запущена, пытаемся перезапустить..."
    try {
        Restart-Service -Name TermService -Force
        Write-Host "✅ Служба удалённого рабочего стола успешно перезапущена"
    } catch {
        Write-Host "❌ Ошибка при перезапуске службы удалённого рабочего стола"
        Log-Error "Ошибка при перезапуске службы TermService"
    }
} else {
    Write-Host "🔹 Служба уже работает, перезапуск не требуется."
}

# Запрос на перезагрузку сервера
$Confirm = Read-Host "Хотите перезагрузить сервер? (Y/N)"
if ($Confirm -match '^(y|Y)$') {
    Write-Host "🔹 Перезагружаем сервер..."
    try {
        Restart-Computer -Force
    } catch {
        Write-Host "❌ Ошибка при перезагрузке сервера"
        Log-Error "Ошибка при перезагрузке сервера"
    }
} else {
    Write-Host "⛔ Перезагрузка отменена"
}
