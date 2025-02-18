# Устанавливаем Execution Policy, если нужно
Set-ExecutionPolicy Unrestricted -Force

# Запрашиваем количество пользователей
$UserCount = Read-Host "Введите количество пользователей для создания"

# Функция генерации случайного пароля (10 символов: верхний, нижний регистр + цифры)
function Generate-Password {
    $length = 10
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $password = -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
    return $password
}

# Создаём пользователей
$UsersList = @()
for ($i=1; $i -le $UserCount; $i++) {
    $Username = "User$i"
    $Password = Generate-Password
    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

    # Создаём пользователя
    New-LocalUser -Name $Username -Password $SecurePassword -FullName "User $i" -Description "RDP User"

    # Добавляем пользователя в группу RDP
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username

    # Запоминаем логины и пароли
    $UsersList += "Логин: $Username | Пароль: $Password"
}

# Сохраняем в файл на рабочем столе
$DesktopPath = [System.Environment]::GetFolderPath('Desktop')
$FilePath = "$DesktopPath\RDP_Users.txt"
$UsersList | Out-File -Encoding UTF8 -FilePath $FilePath

Write-Host "Список пользователей сохранён в $FilePath"

# Запрос на перезагрузку
$Confirm = Read-Host "Хотите перезагрузить сервер? (Y/N)"
if ($Confirm -eq "Y") {
    Restart-Computer -Force
} else {
    Write-Host "Перезагрузка отменена"
}
