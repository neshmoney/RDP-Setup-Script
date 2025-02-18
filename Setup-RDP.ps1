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

# Разрешаем множественные сессии под одной учётной записью
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server" -Name "fSingleSessionPerUser" -Value 0

# Автоматически активируем сервер лицензий
$agreementNumbers = @("6565792", "5296992", "3325596", "4965437", "4526017")
$selectedNumber = $agreementNumbers | Get-Random

Start-Process -FilePath "C:\Windows\System32\lserver.exe" -ArgumentList "/ActivateServer /CompanyName:Test /Country:AF /AgreementNumber:$selectedNumber /LicenseType:2 /LicenseCount:16 /ProductVersion:WindowsServer2022" -Wait

# Запрос на количество пользователей
$userCount = Read-Host "Введите количество пользователей для создания"

# Функция для генерации пароля
function Generate-Password {
    $length = 10
    $lowercase = "abcdefghijklmnopqrstuvwxyz"
    $uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $digits = "0123456789"
    $allChars = $lowercase + $uppercase + $digits
    $password = -join ((1..$length) | ForEach-Object { $allChars | Get-Random })
    return $password
}

# Массив для хранения данных о пользователях
$userCredentials = @()

# Создание пользователей
for ($i = 1; $i -le $userCount; $i++) {
    $username = "User$i"
    $password = Generate-Password
    New-LocalUser -Name $username -Password (ConvertTo-SecureString $password -AsPlainText -Force) -FullName "User $i" -Description "User created by script"
    Add-LocalGroupMember -Group "Users" -Member $username

    # Сохраняем данные в массив
    $userCredentials += "$username : $password"
}

# Сохранение списка логинов и паролей на рабочий стол с кодировкой UTF-8
$userCredentials | Out-File -FilePath "$env:USERPROFILE\Desktop\user_credentials.txt" -Encoding UTF8

# Перезагружаем сервер для применения всех изменений
Restart-Computer -Force
