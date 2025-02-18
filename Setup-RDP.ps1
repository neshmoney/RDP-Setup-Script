# Vklyuchayem sluzhbu Windows Remote Management
Enable-PSRemoting -Force
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Ustanavlivaem roli dlya RDS
Install-WindowsFeature RDS-RD-Server, RDS-Licensing -IncludeManagementTools

# Zhdyom zaversheniya ustanovki i sistemy
Start-Sleep -Seconds 60

# Nastroym licencirovanie cherez reestr
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "LicensingMode" -Value 2
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "SpecifiedLicenseServerList" -Value "127.0.0.1"

# Razreshayem mnozhestvennye sessii pod odnoj uchetnoj zapisi
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server" -Name "fSingleSessionPerUser" -Value 0

# Avtomaticheski aktiviruem server licenziy (proverka nalichiya lserver.exe)
$agreementNumbers = @("6565792", "5296992", "3325596", "4965437", "4526017")
$selectedNumber = $agreementNumbers | Get-Random

if (Test-Path "C:\Windows\System32\lserver.exe") {
    # Komanda dlya aktivacii licenziy
    Start-Process -FilePath "C:\Windows\System32\lserver.exe" -ArgumentList "/ActivateServer /CompanyName:Test /Country:AF /AgreementNumber:$selectedNumber /LicenseType:2 /LicenseCount:16 /ProductVersion:WindowsServer2022" -Wait
} else {
    Write-Host "Fayl lserver.exe ne nayden. Propusk aktivacii licenziy."
}

# Zhdyom zaversheniya raboty sistemy
Start-Sleep -Seconds 60

# Funkciya generacii sluchaynogo parolya (12 simvolov)
function Generate-Password {
    param([int]$length = 12)
    $characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+'
    -join (1..$length | ForEach-Object { $characters[(Get-Random -Minimum 0 -Maximum $characters.Length)] })
}

# Zapros kolichestva polzovateley s proverkoy korrektnosti vvodu
do {
    $numberOfUsers = Read-Host "Vvedite kolichestvo sozdavaemykh polzovateley (chislo ot 1 do 100)"
} while (-not ($numberOfUsers -match '^\d+$') -or [int]$numberOfUsers -lt 1 -or [int]$numberOfUsers -gt 100)

$numberOfUsers = [int]$numberOfUsers

# Opredelyaem put k rabochemu stolu
$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$outputFile = "$desktopPath\user_credentials.txt"

# Ochiщaem fayl pered zapisej
"" | Out-File -FilePath $outputFile -Encoding UTF8

# Sozdanie polzovateley i zapic dannykh v fayl
$credentials = @()
for ($i = 1; $i -le $numberOfUsers; $i++) {
    $username = "user$i"
    $password = Generate-Password 12  # 12 simvolov
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    try {
        # Proveryaem, sushchestvuet li uzhe takoy polzovatel
        if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
            Write-Host "Polzovatel $username uzhe sushchestvuet, propuskayem..."
            continue
        }

        # Sozdaem novogo polzovatelya
        New-LocalUser -Name $username -Password $securePassword -FullName "User $i" -Description "Avtomaticheski sozdannyj polzovatel" -ErrorAction Continue
        Add-LocalGroupMember -Group "Users" -Member $username -ErrorAction Continue
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $username -ErrorAction Continue

        # Dobavlyaem login i parol v massiv
        $credentials += "Login: $username, Parol: $password"

        Write-Host "Sozdan polzovatel: $username s parolem: $password i dobavlen v Remote Desktop Users"
    } catch {
        Write-Host ("Oshibka pri sozdanii polzovatelya {0}: {1}" -f $username, $_.Exception.Message)
    }
}

# Zapisyvayem uchetniye dannye v fayl
if ($credentials.Count -gt 0) {
    $credentials | Out-File -FilePath $outputFile -Encoding UTF8
    Write-Host "Fayl s uchetnymi dannymi soxranen: $outputFile"
} else {
    Write-Host "Oshibka! Polzovatelya ne byli sozdany, fayl ne zapisann."
}

# Zaprosim podtverzhdenie perezagruzki
$restartConfirmed = Read-Host "Skript zavershen. Hotite perezagruzit' server? (Y/N)"
if ($restartConfirmed -eq 'Y') {
    Restart-Computer -Force
}
