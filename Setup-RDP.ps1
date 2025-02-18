# Включаем службу Windows Remote Management
Enable-PSRemoting -Force
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Устанавливаем роли для RDS
Install-WindowsFeature RDS-RD-Server, RDS-Licensing -IncludeManagementTools
Restart-Computer -Force

# Ждём загрузки системы перед продолжением
Start-Sleep -Seconds 60

# Настраиваем лицензирование через реестр
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "LicensingMode" -Value 2
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "SpecifiedLicenseServerList" -Value "127.0.0.1"

# Разрешаем множественные сессии под одной учётной записью
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server" -Name "fSingleSessionPerUser" -Value 0

# Автоматически активируем сервер лицензий
$agreementNumbers = @("6565792", "5296992", "3325596", "4965437", "4526017")
$selectedNumber = $agreementNumbers | Get-Random

Start-Process -FilePath "C:\Windows\System32\lserver.exe" -ArgumentList "/ActivateServer /CompanyName:Test /Country:AF /AgreementNumber:$selectedNumber /LicenseType:2 /LicenseCount:16 /ProductVersion:WindowsServer2022" -Wait

# Запрашиваем количество пользователей
$UserCount = Read-Host "Введите количество пользователей для создания"
$OutputFile = "$env:USERPROFILE\Desktop\RDP_Users.txt"

# Функция генерации случайного пароля
function Generate-Password {
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    -join ((1..10) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

# Создаём пользователей и записываем в файл
$UserList = @()
for ($i = 1; $i -le $UserCount; $i++) {
    $username = "rdpuser$i"
    $password = Generate-Password
    
    New-LocalUser -Name $username -Password (ConvertTo-SecureString $password -AsPlainText -Force) -FullName "RDP User $i" -Description "Удалённый пользователь"
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $username
    
    $UserList += "Логин: $username | Пароль: $password"
}

$UserList | Out-File -Encoding UTF8 $OutputFile

Write-Host "Пользователи созданы! Данные сохранены в файле: $OutputFile"

# Перезагружаем сервер для применения всех изменений
Restart-Computer -Force
