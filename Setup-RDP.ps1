# Включаем службу Windows Remote Management (WinRM) для удаленных подключений
Enable-PSRemoting -Force
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Устанавливаем роли для удаленного рабочего стола
Install-WindowsFeature RDS-RD-Server, RDS-Licensing -IncludeManagementTools

# Ждем завершения установки и системы
Start-Sleep -Seconds 60

# Настроим лицензирование через реестр
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "LicensingMode" -Value 2
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "SpecifiedLicenseServerList" -Value "127.0.0.1"

# Разрешаем множественные сессии под одной учетной записью
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server" -Name "fSingleSessionPerUser" -Value 0

# Настройка блокировки количества подключений RDP
# Разрешаем множество RDP сессий с одинаковыми пользователями
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "MaxInstanceCount" -Value 100

# Устанавливаем максимальное количество сессий
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0

# Функция генерации случайного пароля
function Generate-Password {
    param([int]$length = 12)
    $characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+'
    -join (1..$length | ForEach-Object { $characters[(Get-Random -Minimum 0 -Maximum $characters.Length)] })
}

# Запрос количества пользователей с проверкой правильности ввода
do {
    $numberOfUsers = Read-Host "Введите количество создаваемых пользователей (число от 1 до 100)"
} while (-not ($numberOfUsers -match '^\d+$') -or [int]$numberOfUsers -lt 1 -or [int]$numberOfUsers -gt 100)

$numberOfUsers = [int]$numberOfUsers

# Путь к рабочему столу
$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$outputFile = "$desktopPath\user_credentials.txt"

# Очистка файла перед записью
"" | Out-File -FilePath $outputFile -Encoding UTF8

# Массив для хранения данных пользователей
$credentials = @()

# Создание пользователей и запись их данных в файл
for ($i = 1; $i -le $numberOfUsers; $i++) {
    $username = "user$i"
    $password = Generate-Password 12  # Генерация пароля из 12 символов
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    try {
        # Проверяем, существует ли уже такой пользователь
        if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
            Write-Host "Пользователь $username уже существует, пропускаем..."
            continue
        }

        # Создаем нового пользователя
        New-LocalUser -Name $username -Password $securePassword -FullName "User $i" -Description "Автоматически созданный пользователь" -ErrorAction Continue
        Add-LocalGroupMember -Group "Users" -Member $username -ErrorAction Continue
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $username -ErrorAction Continue

        # Добавляем логин и пароль в массив
        $credentials += "Login: $username, Пароль: $password"

        Write-Host "Создан пользователь: $username с паролем: $password и добавлен в Remote Desktop Users"
    } catch {
        Write-Host ("Ошибка при создании пользователя {0}: {1}" -f $username, $_.Exception.Message)
    }
}

# Записываем учетные данные в файл
if ($credentials.Count -gt 0) {
    $credentials | Out-File -FilePath $outputFile -Encoding UTF8
    Write-Host "Файл с учетными данными сохранен: $outputFile"
} else {
    Write-Host "Ошибка! Пользователи не были созданы, файл не записан."
}

# Подтверждение перезагрузки
$restartConfirmed = Read-Host "Скрипт завершен. Хотите перезагрузить сервер? (Y/N)"
if ($restartConfirmed -eq 'Y') {
    Restart-Computer -Force
}

