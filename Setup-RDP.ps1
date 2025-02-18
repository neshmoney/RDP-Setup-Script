# Устанавливаем Execution Policy, если нужно
Set-ExecutionPolicy Unrestricted -Force

# Проверка на права администратора
$IsAdmin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $IsAdmin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ Ошибка! Запустите PowerShell с правами администратора." -ForegroundColor Red
    exit
}

# Запрос количества пользователей (только числа)
do {
    $UserCount = Read-Host "Введите количество пользователей для создания"
} while ($UserCount -match '\D' -or [int]$UserCount -le 0)

# Функция генерации случайного пароля (12 символов: буквы разного регистра + цифры + спецсимволы)
function Generate-Password {
    $length = 12
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}

# Создаём пользователей
$UsersList = @()
for ($i = 1; $i -le $UserCount; $i++) {
    $Username = "User$i"
    $Password = Generate-Password
    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

    # Проверяем, существует ли пользователь
    if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
        Write-Host "⚠️ Пользователь $Username уже существует, пропускаем..."
        continue
    }

    try {
        # Создаём пользователя
        New-LocalUser -Name $Username -Password $SecurePassword -FullName "RDP User $i" -Description "RDP User" -ErrorAction Stop

        # Добавляем пользователя в группу RDP
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction Stop

        # Добавляем в список
        $UsersList += "Логин: $Username | Пароль: $Password"
        Write-Host "✅ Пользователь $Username создан и добавлен в RDP-группу"
    } catch {
        Write-Host "❌ Ошибка при создании пользователя $Username: $_" -ForegroundColor Red
    }
}

# Сохраняем в файл на рабочем столе
$DesktopPath = [System.Environment]::GetFolderPath('Desktop')
$FilePath = "$DesktopPath\RDP_Users.txt"
$UsersList | Out-File -FilePath $FilePath -Encoding utf8

Write-Host "📂 Список пользователей сохранён в: $FilePath"

# Настраиваем RDP (многопользовательский режим)
Write-Host "🔹 Настраиваем RDP для одновременных подключений..."

Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fSingleSessionPerUser" -Value 0
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\Licensing Core" -Name "EnableConcurrentSessions" -Value 1
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\TermService" -Name "Start" -Value 2

# Увеличиваем количество подключений
Write-Host "🔹 Увеличиваем число разрешённых одновременных подключений..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxInstanceCount" -Value 999999

# Отключаем ограничение по времени неактивных сессий
Write-Host "🔹 Отключаем ограничение по времени неактивных RDP-сессий..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxIdleTime" -Value 0

# Перезапускаем RDP-сервис
Write-Host "🔄 Перезапускаем службу удалённого рабочего стола..."
Restart-Service -Name TermService -Force

Write-Host "✅ Готово! Теперь сервер поддерживает несколько RDP-сессий."
