# Устанавливаем Execution Policy, если нужно
Set-ExecutionPolicy Unrestricted -Force

# Запрашиваем количество пользователей (проверка на ввод чисел)
do {
    $UserCount = Read-Host "Введите количество пользователей для создания"
} while ($UserCount -match '\D' -or [int]$UserCount -le 0)

# Функция генерации случайного пароля (12 символов: буквы, цифры и спецсимволы)
function Generate-Password {
    $length = 12
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+[]{}|;:,.<>?"
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}

# Создаём пользователей
$UsersList = @()
for ($i=1; $i -le $UserCount; $i++) {
    $Username = "User$i"
    $Password = Generate-Password
    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

    # Проверка на существование пользователя
    if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
        Write-Host "❌ Пользователь с именем $Username уже существует. Пропускаем."
        continue
    }

    # Создаём пользователя
    try {
        New-LocalUser -Name $Username -Password $SecurePassword -FullName "User $i" -Description "RDP User" -ErrorAction Stop
        Write-Host "✅ Пользователь $Username успешно создан"
    } catch {
        Write-Host "❌ Ошибка при создании пользователя $Username: $_"
        continue
    }

    # Добавляем пользователя в группу RDP
    try {
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction Stop
        Write-Host "✅ Пользователь $Username добавлен в группу Remote Desktop Users"
    } catch {
        Write-Host "❌ Ошибка при добавлении пользователя $Username в группу: $_"
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
if (Test-Path "HKLM:\System\CurrentControlSet\Control\Terminal Server") {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fSingleSessionPerUser" -Value 0
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\Licensing Core" -Name "EnableConcurrentSessions" -Value 1
    Write-Host "✅ Разрешено несколько одновременных RDP-сессий."
} else {
    Write-Host "⚠ Путь 'HKLM:\System\CurrentControlSet\Control\Terminal Server' не найден!"
}

# Увеличиваем число разрешённых сессий
Write-Host "🔹 Увеличиваем число разрешённых одновременных подключений..."
if (Test-Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp") {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxInstanceCount" -Value 999999
    Write-Host "✅ Число разрешённых одновременных подключений увеличено."
} else {
    Write-Host "⚠ Путь 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' не найден!"
}

# Отключаем ограничение по времени неактивных сессий
Write-Host "🔹 Отключаем ограничение по времени неактивных RDP-сессий..."
if (Test-Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp") {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxIdleTime" -Value 0
    Write-Host "✅ Ограничение по времени неактивных сессий отключено."
} else {
    Write-Host "⚠ Путь 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' не найден!"
}

# Перезапуск службы RDP
$ConfirmServiceRestart = Read-Host "Хотите перезапустить службу RDP? (Y/N)"
if ($ConfirmServiceRestart -match '^(y|Y)$') {
    try {
        Restart-Service -Name TermService -Force -ErrorAction Stop
        Write-Host "✅ Служба удалённого рабочего стола успешно перезапущена"
    } catch {
        Write-Host "❌ Ошибка при перезапуске службы удалённого рабочего стола: $_"
    }
} else {
    Write-Host "⛔ Перезапуск службы отменён"
}

# Запрос на перезагрузку
$Confirm = Read-Host "Хотите перезагрузить сервер? (Y/N)"
if ($Confirm -match '^(y|Y)$') {
    Restart-Computer -Force
} else {
    Write-Host "⛔ Перезагрузка отменена"
}
