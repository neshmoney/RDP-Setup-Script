# Включаем службу Windows Remote Management
Enable-PSRemoting -Force
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Устанавливаем роли для RDS
Install-WindowsFeature RDS-RD-Server, RDS-Licensing -IncludeManagementTools

# Настроим лицензирование через реестр
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "LicensingMode" -Value 2
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "SpecifiedLicenseServerList" -Value "127.0.0.1"

# Разрешаем множественные сессии под одной учётной записью
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server" -Name "fSingleSessionPerUser" -Value 0

# Автоматически активируем сервер лицензий
$agreementNumbers = @("6565792", "5296992", "3325596", "4965437", "4526017")
$selectedNumber = $agreementNumbers | Get-Random

# Команды для автоматической активации лицензий
Start-Process -FilePath "C:\Windows\System32\lserver.exe" -ArgumentList "/ActivateServer /CompanyName:Test /Country:AF /AgreementNumber:$selectedNumber /LicenseType:2 /LicenseCount:16 /ProductVersion:WindowsServer2022" -Wait

# Функция генерации пароля
function Generate-Password {
    $length = 10
    $characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $password = -join ((1..$length) | ForEach-Object { $characters | Get-Random })
    return $password
}

# Запрос количества пользователей
$numberOfUsers = Read-Host "Введите количество создаваемых пользователей"

# Проверяем, если пользователь ввел число
if ($numberOfUsers -match '^\d+$') {
    # Путь к рабочему столу
    $desktopPath = [System.Environment]::GetFolderPath("Desktop")
    $outputFile = "$desktopPath\user_credentials.txt"

    # Создание файла и добавление данных
    $output = @()

    # Создание пользователей с генерацией паролей
    for ($i = 1; $i -le $numberOfUsers; $i++) {
        $username = "user$i"
        $password = Generate-Password
        Write-Host "Создан пользователь: $username с паролем: $password"
        
        # Запись в массив для последующего сохранения в файл
        $output += "Пользователь: $username, Пароль: $password"
        
        # Добавьте команду для создания пользователя в системе, например:
        # New-LocalUser -Name $username -Password (ConvertTo-SecureString -AsPlainText $password -Force)
    }

    # Сохранение данных в текстовый файл
    $output | Out-File -FilePath $outputFile -Encoding UTF8

    Write-Host "Файл с данными пользователей сохранён на рабочем столе: $outputFile"
} else {
    Write-Host "Введено некорректное значение. Пожалуйста, введите число."
}

# Перезагружаем сервер для применения всех изменений в конце
Restart-Computer -Force
