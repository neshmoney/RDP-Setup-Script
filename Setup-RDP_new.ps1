# Устанавливаем Execution Policy, если нужно
Set-ExecutionPolicy Unrestricted -Force

# Запрашиваем количество пользователей (проверка на ввод чисел)
do {
    $UserCount = Read-Host "Введите количество пользователей для создания"
} while (-not $UserCount -match '^\d+$' -or [int]$UserCount -le 0)

# Функция генерации случайного пароля (по умолчанию 10 символов)
function Generate-Password {
    param (
        [int]$length = 10
    )
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}

# Создаём пользователей
$UsersList = @()
for ($i = 1; $i -le $UserCount; $i++) {
    $Username = "User$i"
    $Password = Generate-Password
    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

    # Создаём пользователя
    try {
        New-LocalUser -Name $Username -Password $SecurePassword -FullName "User $i" -Description "RDP User" -ErrorAction Stop
        Write-Host "✅ Пользователь $Username успешно создан"
    } catch {
        Write-Host "❌ Ошибка при создании пользователя $Username: $($Error[0].Exception.Message)"
        continue
    }

    # Добавляем пользователя в группу RDP
    try {
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction Stop
        Write-Host "✅ Пользователь $Username добавлен в группу Remote Desktop Users"
    } catch {
        Write-Host "❌ Ошибка при добавлении пользователя $Username в группу: $($Error[0].Exception.Message)"
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

# Увеличиваем число разрешённых сессий
Write-Host "🔹 Увеличиваем число разрешённых одновременных подключений..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxInstanceCount" -Value 999999
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanServer\Parameters" -Name "MaxMpxCt" -Value 65535
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanServer\Parameters" -Name "MaxWorkItems" -Value 8192

# Отключаем ограничение по времени неактивных сессий
Write-Host "🔹 Отключаем ограничение по времени неактивных RDP-сессий..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxIdleTime" -Value 0

# Перезапускаем службу RDP
Write-Host "🔹 Перезапускаем службу удалённого рабочего стола..."
try {
    Restart-Service -Name TermService -Force -ErrorAction Stop
    Write-Host "✅ Служба удалённого рабочего стола успешно перезапущена"
} catch {
    Write-Host "❌ Ошибка при перезапуске службы удалённого рабочего стола: $($Error[0].Exception.Message)"
}

# Запрос на перезагрузку
$Confirm = Read-Host "Хотите перезагрузить сервер? (Y/N)"
if ($Confirm -match '^(y|Y)$') {
    Restart-Computer -Force
} else {
    Write-Host "⛔ Перезагрузка отменена"
}
