
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()

    $p = New-Object System.Security.Principal.WindowsPrincipal($id)

    if ($p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)){

    cls
    write-host ""
    Write-host "Running As Administrator..." -ForegroundColor Green
    write-host ""
     
write-host "======Current IPv6 Status======" -ForegroundColor cyan
get-NetAdapterBinding -Name '*' -ComponentID 'ms_tcpip6' -verbose
write-host ""
write-host "======IPv6 Toggle======" -ForegroundColor cyan
$Question = read-host -Prompt "Type: Disable or Enable 
=======================
" 

if ($question -like 'enable'){

enable

}

if ($question -like 'disable'){

disable

}

function enable {

write-host ""
write-host "Enabling IPv6..." -ForegroundColor green
write-host ""
Enable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -verbose
write-host ""


}

function disable {
write-host ""
write-host "Disabling IPv6..." -ForegroundColor green
write-host ""
Disable-NetAdapterBinding -Name '*' -ComponentID 'ms_tcpip6' -verbose
write-host ""
}


$gnab = get-NetAdapterBinding -Name '*' -ComponentID 'ms_tcpip6' -verbose

if ($gnab.enabled -eq $False){

write-host 'IPv6 has been disabled'

}else{

write-host 'IPv6 has been enabled'

}
write-host ""

write-host "======Current IPv6 Status======" -ForegroundColor cyan
get-NetAdapterBinding -Name '*' -ComponentID 'ms_tcpip6' -verbose








     }else{
     

     write-host ""
     Write-host "Must Run As Administrator..." -ForegroundColor Yellow
     write-host ""
     write-host ""
     pause
     } 




