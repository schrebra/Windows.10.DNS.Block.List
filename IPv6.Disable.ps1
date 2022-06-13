
write-host ""
write-host "Disabling IPv6 ..." -ForegroundColor green
write-host ""
Disable-NetAdapterBinding -Name '*' -ComponentID 'ms_tcpip6'

write-host "============IPv6 Status============" -ForegroundColor Magenta
get-NetAdapterBinding -Name '*' -ComponentID 'ms_tcpip6' | format-table -AutoSize -Property Name, Enabled 






