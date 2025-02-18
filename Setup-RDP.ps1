Enable-PSRemoting -Force
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

Install-WindowsFeature RDS-RD-Server, RDS-Licensing -IncludeManagementTools

Start-Sleep -Seconds 60

Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "LicensingMode" -Value 2
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "SpecifiedLicenseServerList" -Value "127.0.0.1"

Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server" -Name "fSingleSessionPerUser" -Value 0

$agreementNumbers = @("6565792", "5296992", "3325596", "4965437", "4526017")
$selectedNumber = $agreementNumbers | Get-Random

if (Test-Path "C:\Windows\System32\lserver.exe") {
    Start-Process -FilePath "C:\Windows\System32\lserver.exe" -ArgumentList "/ActivateServer /CompanyName:Test /Country:AF /AgreementNumber:$selectedNumber /LicenseType:2 /LicenseCount:16 /ProductVersion:WindowsServer2022" -Wait
} else {
    Write-Host "Файл lserver.exe не найден. Пропуск активации лицензий."
}

Start-Sleep -Seconds 60

function Generate-Password {
    param([int]$length = 12)
    $characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+'
    -join (1..$length | ForEach-Object { $characters[(Get-Random -Minimum 0 -Maximum $characters.Length)] })
}

do {
    $numberOfUsers = Read-Host "Введите количество создаваемых пользователей (число от 1 до 100)"
} while (-not ($numberOfUsers -match '^\d+$') -or [int]$numberOfUsers -lt 1 -or [int]$numberOfUsers -gt 100)

$numberOfUsers = [int]$numberOfUsers

$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$outputFile = "$desktopPath\user_credentials.txt"

"" | Out-File -FilePath $outputFile -Encoding UTF8

$credentials = @()
for ($i = 1; $i -le $numberOfUsers; $i++) {
    $username = "user$i"
    $password = Generate-Password 12
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    try {
        if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
            Write-Host "Пользователь $username уже существует, пропускаем..."
            continue
        }

        New-LocalUser -Name $username -Password $securePassword -FullName "User $i" -Description "Автоматически созданный пользователь" -ErrorAction Continue
        Add-LocalGroupMember -Group "Users" -Member $username -ErrorAction Continue
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $username -ErrorAction Continue

        $credentials += "Логин: $username, Пароль: $password"

        Write-Host "Создан пользователь: $username с паролем: $password и добавлен в Remote Desktop Users"
    } catch {
        Write-Host ("Ошибка при создании пользователя {0}: {1}" -f $username, $_.Exception.Message)
    }
}

if ($credentials.Count -gt 0) {
    $credentials | Out-File -FilePath $outputFile -Encoding UTF8
    Write-Host "Файл с учетными данными сохранен: $outputFile"
} else {
    Write-Host "Ошибка! Пользователи не были созданы, файл не записан."
}

$restartConfirmed = Read-Host "Скрипт завершен. Хотите перезагрузить сервер? (Y/N)"
if ($restartConfirmed -eq 'Y') {
    Restart-Computer -Force
}
