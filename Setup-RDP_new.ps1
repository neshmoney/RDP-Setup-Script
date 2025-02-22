# Запрос количества пользователей
$UserCount = Read-Host "Введите количество пользователей для создания"

# Функция генерации пароля
function Generate-Password {
    param (
        [int]$length = 12
    )
    $Chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()'
    return -join (Get-Random -Count $length -InputObject $Chars.ToCharArray())
}

# Создание пользователей
for ($i = 1; $i -le $UserCount; $i++) {
    $Username = "User$i"
    $Password = Generate-Password

    try {
        # Создание пользователя
        New-LocalUser -Name $Username -Password (ConvertTo-SecureString -String $Password -AsPlainText -Force) -FullName $Username -Description "RDP User" -ErrorAction Stop

        # Добавление пользователя в группу "Пользователи удаленного рабочего стола"
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction Stop

        Write-Host "✅ Пользователь $Username создан."
    }
    catch {
        Write-Host "❌ Ошибка при создании пользователя $Username. $_"
    }
}

# Сохранение списка пользователей на рабочий стол
$UsersFile = "$env:USERPROFILE\Desktop\RDP_Users.txt"
$UsersList = @()
for ($i = 1; $i -le $UserCount; $i++) {
    $UsersList += "User$i"
}
$UsersList | Out-File -Encoding UTF8 -FilePath $UsersFile
Write-Host "✅ Список пользователей сохранён в $UsersFile"

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

Write-Host "🔹 Настройка RDP завершена."

# Запрос на перезагрузку
$Restart = Read-Host "Хотите перезагрузить сервер? (Y/N)"
if ($Restart -eq "Y") {
    Restart-Computer -Force
} else {
    Write-Host "⛔ Перезагрузка отменена."
}
