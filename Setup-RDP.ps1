# Включаем службу Windows Remote Management
Enable-PSRemoting -Force
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Устанавливаем роли для RDS
Install-WindowsFeature RDS-RD-Server, RDS-Licensing -IncludeManagementTools
Restart-Computer -Force

# Ждём загрузки системы перед продолжением
Start-Sleep -Seconds 60

# Настроим лицензирование через реестр
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "LicensingMode" -Value 2
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "SpecifiedLicenseServerList" -Value "127.0.0.1"

# Разрешаем множественные сессии под одной учетной записью
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server" -Name "fSingleSessionPerUser" -Value 0

# Автоматически активируем сервер лицензий
$agreementNumbers = @("6565792", "5296992", "3325596", "4965437", "4526017")
$selectedNumber = $agreementNumbers | Get-Random

# Команда для активации лицензий
Start-Process -FilePath "C:\Windows\System32\lserver.exe" -ArgumentList "/ActivateServer /CompanyName:Test /Country:AF /AgreementNumber:$selectedNumber /LicenseType:2 /LicenseCount:16 /ProductVersion:WindowsServer2022" -Wait

# Перезагружаем сервер для применения всех изменений
Restart-Computer -Force

# Ждём загрузки системы перед созданием пользователей
Start-Sleep -Seconds 60

# Функция генерации случайного пароля (12 символов)
function Generate-Password {
    param([int]$length = 12)
    $characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+'
    -join (1..$length | ForEach-Object { $characters[(Get-Random -Minimum 0 -Maximum $characters.Length)] })
}

# Запрос количества пользователей с проверкой корректности ввода
do {
    $numberOfUsers = Read-Host "Введите количество создаваемых пользователей (число от 1 до 100)"
} while (-not ($numberOfUsers -match '^\d+$') -or [int]$numberOfUsers -lt 1 -or [int]$numberOfUsers -gt 100)

$numberOfUsers = [int]$numberOfUsers

# Определяем путь к рабочему столу
$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$outputFile = "$desktopPath\user_credentials.txt"

# Очищаем файл перед записью
"" | Out-File -FilePath $outputFile -Encoding UTF8

# Создание пользователей и запись данных в файл
$credentials = @()
for ($i = 1; $i -le $numberOfUsers; $i++) {
    $username = "user$i"
    $password = Generate-Password 12  # 12 символов
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    try {
        # Проверяем, существует ли уже такой пользователь
        if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
            Write-Host "Пользователь $username уже существует, пропускаем..."
            continue
        }

        # Создаем нового пользователя
        New-LocalUser -Name $username -Password $securePassword -FullName "User $i" -Description "Автоматически созданный пользователь" -ErrorAction Stop
        Add-LocalGroupMember -Group "Users" -Member $username -ErrorAction Stop
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $username -ErrorAction Stop

        # Добавляем логин и пароль в массив
        $credentials += "Логин: $username, Пароль: $password"

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
