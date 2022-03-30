
# DNS Block List for Windows 10 [![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fschrebra%2FWindows.10.DNS.Block.List&count_bg=%23C83D3D&title_bg=%23000000&icon=buzzfeed.svg&icon_color=%23EF6969&title=Page+Views&edge_flat=false)](https://hits.seeyoufarm.com)

**The Largest List of Windows hosts - 3,171 Hosts**

-Includes Windows 10 and Windows 11-

This is an exhaustive list of all Windows DNS names that call back to Microsoft.

## Pihole Adlist URL 
- https://raw.githubusercontent.com/schrebra/Windows.10.DNS.Block.List/main/hosts.txt

## Warning

Blocking includes any built in apps
> Bing, Outlook, Office, Edge, Skype, Xbox, Microsoft.com, Windows Update, Defender Update, Azure, OneDrive, Spotify,TikTok, Clipchamp, Facebook, Linkedin and Telemetry.

## Broken Network Icon Fix
The network icon will show that you have no internet connectivity, this is because of msftconnecttest.com. Occasionally your browser will pop open and go to this domain to force a connection home. It won't work and the page will be blank. To fix this go to networkproguide.com link below to modify your registry settings.

- https://networkproguide.com/fix-connect-attempts-to-www-msftconnecttest-com-windows-server-2016/

## Optional security

I wouldn't recommend doing this but if you really want to block everything the guide is here to experiment with.
Windows Restricted Traffic Limited Functionality Baseline:
A Microsoft provided package that will allow your organization to quickly configure the settings covered in this document to restrict connections from Windows 10 and Windows 11 to Microsoft.
Download Windows Restricted Traffic Limited Functionality Baseline zip file and run the powershell script. This will break browsing the internet because of Windows checking https websites against Microsoft Certificate Authorities. To fix this use gpedit.msc and under administrative templates, find the setting for ssl or certificates.

- https://docs.microsoft.com/en-us/windows/privacy/manage-connections-from-windows-operating-system-components-to-microsoft-services

## IP Based Blocking

### Microsoft Public IP space
Microsoft is known to not resolve all DNS names when communicating with Windows
If you have a router firewall you can also block Windows Public Connection Endpoints

- https://www.microsoft.com/en-us/download/details.aspx?id=53602


## Powershell Firewall Blocking
Run powershell as administrator and enter "Set-ExecutionPolicy RemoteSigned"
> - **Block.MSFT.ps1** to block all Microsoft Public IP Space
> - **Unblock.MSFT.ps1** to remove the rules







## Sources

- https://answers.microsoft.com/en-us/windows/forum/windows_other-networking/need-windows-update-servers-ip-address-range-to/0b0d3618-f74c-411d-bb46-58bd605f7abe
- https://docs.microsoft.com/de-de/security-updates/windowsupdateservices/18127640
- https://docs.microsoft.com/en-us/answers/questions/121284/wsus-update-url.html
- https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-troubleshooting#why-am-i-offered-an-older-updateupgrade
- https://docs.microsoft.com/en-us/windows/privacy
- https://superuser.com/questions/363120/block-access-to-windows-update
- https://www.microsoft.com/en-us/download/confirmation.aspx?id=53602
- https://www.reddit.com/r/MoneroMining/comments/8l5wpt/block_windows_update_with_firewall
- https://www.reddit.com/r/sysadmin/comments/g345cj/windows_update_official_list_of_ips_or_domains
- https://www.reddit.com/r/Windows10/comments/3j8909/does_anyone_have_an_exhaustive_list_of_ip_ranges
- https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt
- https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt
- https://gist.githubusercontent.com/amalleo25/eb73bc748029297500e76e7eac41337e/raw/9f5dd17d682b3b9c5b64c253863fcd4d74f9a7c8/telemetry-blocklist
- https://raw.githubusercontent.com/WindowsLies/BlockWindows/master/hostslist
- https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/extra.txt
