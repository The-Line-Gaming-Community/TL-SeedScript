$localVersion = 3.0
$configReq = 3

$latestdl = 'https://od.lk/fl/NjJfMzM2NDI2M18'
$elevate = "false"

#######################################################################################################################################
# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000 -and $elevate -eq "true") {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
        Exit
    }
}

#Generate Settings File
$mydocs = [Environment]::GetFolderPath("MyDocuments")
if(Test-Path -Path $mydocs/seedscript/settings.txt){
    
}else{
    #Dont edit these, this is simply for the settings generation
    $settings = "[GENERAL]
    # 1 = true | enabled
    # 0 = false | disabled

    # Show Warning at script start. Recommended you only disable this after you set it up so you can read the prompt.
    iKnowWhatImDoing=0

    # Move console to seeding desktop
    # Remember Win+Tab to switch desktops
    moveConsole=0

    # Closes game after looping through once
    # Reopens if a server requires seeding (If super seeding is enabled)
    # This could be annoying if you wanted to play the game while seeding.
    closeGame=1

    # Kills the game if the seeding batch is terminated
    # This could be annoying if you wanted to play the game while seeding and batch terminated.
    closeGameConsole=1

    # Continuous Seeding
    # If true, loops continuously, otherwise seeds all servers once
    superSeeder=0

    # Scheduler to stop seeding if not in accepted range.
    # seedStart and seedEnd are hour values in the 24h format.
    # i.e 8-18 is 8AM-6PM, 18-8 is 6PM to 8AM.
    schdulerEnabled=0
    seedStart=8
    seedEnd=22

    [ADVANCED]
    # How long in seconds to wait before checking the server for your presence.
    # Extra time after the HLL window opens, for you to join the server.
    launchSleep=60

    # Show Sincestamps (How long you've been seeding current server).
    sincestamp=1

    # Show Timestamps
    timestamps=1

    # Number of population to wait before disconnecting and moving on.
    popGoal=60

    # Wait for input after seeding completes (If superseeding is disabled)
    # Allowing user to read the log.
    waitForInput=1

    # How often in seconds to repeate main loop (Check current pop).
    # This increases API calls, be careful. 100k rate limit per day. (Recommended value above 10)
    loopSleep=60

    # Check for updates?
    updater=1

    # Verbose outputs for debug or nerds.
    verbose=0

    # How often to check other servers
    checkOtherServersIntervalMinutes=15

    # DONT CHANGE THIS
    version=3"
    if(-not (Test-Path $mydocs/seedscript/)){
        New-Item -Path $mydocs/seedscript/ -ItemType Directory | Out-Null
    }
    $settings | Out-File -FilePath $mydocs/seedscript/settings.txt
}

#############################################################################################

Write-Host ""
Write-Host "     -The Line- Seeding Script     "  -ForegroundColor Magenta
Write-Host ""
Write-Host ""
Write-Host "original idea and implementation by" -ForegroundColor Magenta
Write-Host "              Tommy                " -ForegroundColor Magenta
Write-Host ""
Write-Host "      additional features by       " -ForegroundColor Magenta
Write-Host "           SwedishNinja            " -ForegroundColor Magenta
Write-Host ""
Write-Host "VERSION :" $localversion
Write-Host ""
Write-Host ""
Write-Host "Preparing..." -ForegroundColor Black -BackgroundColor White -NoNewline

$count = 6
do{
    $count = $count - 1
    Write-Host "." $count -ForegroundColor Black -BackgroundColor White -NoNewline
    Start-Sleep -Seconds 1
}while ($count -gt 1)
Write-Host ""

Function timestamp {
    (&{If($setting.timestamps) {(Get-Date -Format "[hh:mm]")}})
}

#Imports settings.txt and adds them to a hashmap.
Get-Content -Path "$mydocs\seedscript\settings.txt" |
    foreach-object `
        -begin {
            $setting=@{}
        } `
        -process {
            $k = [regex]::split($_,'=')
            if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True))
            {
                $setting.Add($k[0], $k[1])
            }
        }

#Config Borked
if($configReq -gt ($setting.version)){
    Write-Host `n
    Write-Host "################################################################################" -ForegroundColor red
    Write-Host "#-----------------------  CONFIG NEEDS TO BE UPDATED!  ------------------------#" -ForegroundColor red
    Write-Host "#----------  THIS WILL DELETE THE OLD CONFIG AND GENERATE A NEW ONE  ----------#" -ForegroundColor red
    Write-Host "#------------  IF YOU MADE CHANGES TO IT, YOU NEED TO REDO THEM  --------------#" -ForegroundColor red
    Write-Host "################################################################################" -ForegroundColor red
    Write-Host ""
    $choice = Read-Host -Prompt 'Would you like to delete it now? (y/n)'

    if($choice -eq 'y' -or $choice -eq 'yes'){
        Remove-Item $mydocs/seedscript/settings.txt
        break
    } else{
        ii $mydocs/seedscript/
        break
    }
}

#Map Settings to local vars
$iKnowWhatImDoing = ($setting.iKnowWhatImDoing)
$launchSleep = ($setting.launchSleep)
$moveConsole = ($setting.moveConsole)
$popGoal = ($setting.popGoal)
$loopSleep = ($setting.loopSleep)
$closeGameConsole = ($setting.closeGameConsole)
$closeGame = ($setting.closeGame)
$tl = ($setting.timestamps)
$serversFromWeb = ((Invoke-webrequest -UseBasicParsing -URI "http://131.153.65.166/files/seedscript/servers.txt").Content).Split(",")
$verbose = ($setting.verbose)
$updater = ($setting.updater)
$waitForInput = ($setting.waitForInput)
$scheduler = ($setting.schdulerEnabled)
$seedStart = [int]($setting.seedStart)
$seedEnd = [int]($setting.seedEnd)
$checkOtherServersIntervalMinutes = [int]($setting.checkOtherServersIntervalMinutes)

if ($checkOtherServersIntervalMinutes -eq 0) {
    Write-Host "Server Interval Check not set: default to 15 minutes"
    $checkOtherServersIntervalMinutes = 15
}

#Create Local Vars
$serverList=[ordered]@{}
$steamDir = Get-ItemProperty -Path Registry::HKEY_CURRENT_USER\SOFTWARE\Valve\Steam -Name SteamExe
$currentlySeeding = ""

#Check for Updates
if($updater -eq 1){
    Write-Host ""
    Write-Host "Checking for Updates..."
    $remoteVersionRaw = (Invoke-webrequest -UseBasicParsing -URI "http://131.153.65.166/files/seedscript/version.txt").Content
    $changeLog = (Invoke-webrequest -UseBasicParsing -URI "http://131.153.65.166/files/seedscript/changelog.txt").Content
    $remoteVersion = [double]$remoteVersionRaw
    Write-Host ""
    if($remoteVersion -gt $localVersion){
        Write-Host "LATEST VERSION :"$($remoteVersion)
        Write-Host "LATEST CHANGELOG :"
        Write-Host ""
        Write-Host $changeLog
        Write-Host ""
        Write-Host "################################################################################" -ForegroundColor red
        Write-Host "#------------------  A NEWER VERSION OF THE SCRIPT EXISTS!  -------------------#" -ForegroundColor red
        Write-Host "#-------  FILE DOWNLOAD PAGE WILL OPEN! REPLACE AND OVERWRITE CURRENT.  -------#" -ForegroundColor red
        Write-Host "################################################################################" -ForegroundColor red
        Write-Host `n
        $choice = Read-Host -Prompt 'Would you like to download it now? (y/n)'
    }
    if($choice -eq 'y' -or $choice -eq 'yes'){
        Start $latestdl
        if($elevate -eq "false"){
            ii .
        }
        break
    }
}

#Scheduler, returns 1/0 if current hour is within configured range.
Function timeframe {
    $hour = [int](Get-Date -Format "HH")
    if($scheduler -eq 0){
        $result = 1
    }
    elseif(($seedStart -le $seedEnd) -and ($hour -ge $seedStart) -and ($hour -lt $seedEnd)){
        $result = 1
    }
    elseif(($seedEnd -le $seedStart) -and (($hour -ge $seedStart) -or ($hour -lt $seedEnd))){
        $result = 1
    }
    else{
        $result = 0
    }
    return $result
}
if(-not (timeframe)){
    Write-Host "The scheduler has prevented seeding." -BackgroundColor Red
    break
}

# Dependancy Checks
if($verbose -eq 1){
    Write-Host "Setting Error Preferences."
    $ErrorActionPreference = "SilentlyContinue"
    Write-Host "Checking Dependancies..."
}
if(-not (Get-Module -ListAvailable -Name SteamPS)){Install-Module SteamPS -Scope CurrentUser -Force}
if(-not (Get-Module -ListAvailable -Name NUGet)){Install-Module NUGet -Scope CurrentUser -Force}
if(-not (Get-Module -ListAvailable -Name VirtualDesktop)){Install-Module VirtualDesktop -Scope CurrentUser -Force}

# Information Notice
if($iKnowWhatImDoing -eq 0){
    Write-Host `n
    Write-Host "################################################################################" -ForegroundColor green
    Write-Host "#------------------------------  PLEASE READ!  --------------------------------#" -ForegroundColor red
    Write-Host "#-----------  ITS IMPORTANT TO UNDERSTAND THIS SCRIPT HIDES THINGS  -----------#" -ForegroundColor green
    Write-Host "#------  WINDOWS WILL VANISH AFTER BREIFLY BEING VISIBLE, THIS IS NORMAL  -----#" -ForegroundColor green
    Write-Host "#----  EVERYTHING IT DOES IS FOUND ON A VIRTUAL DESKTOP CALLED 'SEEDING'  -----#" -ForegroundColor green
    Write-Host "#---------  YOU CAN ACCESS IT ANYTIME WITH THE HOTKEY COMBO WIN+TAB  ----------#" -ForegroundColor green
    Write-Host "#----  IF YOU CANT SEE THAT DESKTOP, SCRIPT HAS COMPLETED, SERVERS FULL??  ----#" -ForegroundColor green
    Write-Host "#---------------  TO END SEEDING, CTRL+C THIS WINDOW ANYTIME  -----------------#" -ForegroundColor green
    Write-Host "################################################################################" -ForegroundColor green
    Write-Host "#--------------- YOU CAN DISABLE THIS WARNING IN THE SETTING FILE -------------#" -ForegroundColor green
    Write-Host "#--------------- SETTINGS FILE IS LOCATED AT DOCUMENTS/SEEDSCRIPT -------------#" -ForegroundColor green
    Write-Host "#-------------------- READ THE README IF YOU NEED MORE HELP -------------------#" -ForegroundColor green
    Write-Host "################################################################################"`n -ForegroundColor green
    Write-Host ""
    Write-Host "Would you like to open the settings directory and configure it now?"
    $choice = Read-Host -Prompt '(y/yes) will open the location, otherwise enter will continue.'
    if($choice -eq 'y' -or $choice -eq 'yes'){
        ii $mydocs/seedscript/
        break
    }
}

# API Key Check
if(Test-Path -Path C:\Users\$env:UserName\AppData\Roaming\SteamPS\SteamPSKey.json){
  
}else{
    Write-Host `n
    Write-Host "################################################################################" -ForegroundColor red
    Write-Host "#----------------------------  NO API KEY FOUND!  -----------------------------#" -ForegroundColor red
    Write-Host "#--------------  PROCEED TO THE BROWSER WINDOW THAT HAS OPENED  ---------------#" -ForegroundColor red
    Write-Host "#--------------  OR GO TO https://steamcommunity.com/dev/apikey  --------------#" -ForegroundColor red
    Write-Host "#--------------------  SIGN INTO STEAM : REGISTER FOR API  --------------------#" -ForegroundColor red
    Write-Host "#-----------  YOU CAN USE LOCALHOST AS DOMAIN NAME : COPY API KEY  ------------#" -ForegroundColor red
    Write-Host "#-------------------  R-CLICK TO PASTE IT IN PROMPT BELOW  --------------------#" -ForegroundColor red
    Write-Host "################################################################################" -ForegroundColor red
    Start https://steamcommunity.com/dev/apikey
    Connect-SteamAPI
}

# Prepares desktop env and moves windows.
if($verbose -eq 1){
    Write-Host "Setting up environment..."
}
if((Get-DesktopIndex -Desktop "Seeding" -erroraction 'silentlycontinue') -eq "-1"){
    New-Desktop | Set-DesktopName -Name "Seeding" | Out-Null
    if($verbose -eq 1){
        Write-Host "Seeding Desktop Created"
    }
}

if($moveConsole -eq 1){
    Get-Desktop ((Get-DesktopCount)-1) | Move-Window (Get-ConsoleHandle) | Out-Null -erroraction 'silentlycontinue'
    if($verbose -eq 1){
        Write-Host "Moved Console"
    }
}

# Exit events to restore desktops to normal.
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting {
    Write-Host `n "Script Terminated. Cleaning up... " -ForegroundColor Black -BackgroundColor White
    Stop-Process -Name 'HLL-Win64-Shipping' -Force
    Remove-Desktop -Desktop "Seeding" | Out-Null  -erroraction 'silentlycontinue'
    Get-Desktop (0) | Switch-Desktop | Move-Window (Get-ConsoleHandle) | Out-Null  -erroraction 'silentlycontinue'
    Start-Sleep -Seconds 5
}
if($verbose -eq 1){
    Write-Host "Registered Exit Events"
}

# Get SteamID3 from RegistryKey and Convert it to SteamID64
if($verbose -eq 1){
    Write-Host "Setting SteamID..."
}
$SteamIDKey = reg query HKEY_CURRENT_USER\SOFTWARE\Valve\Steam\ActiveProcess /v ActiveUser
$SteamID3 = [uint32]($SteamIDKey[2] -replace ".*(?=0x)","")
if ($SteamID3 % 2 -eq 0){
    $Y = 0
    $Z = $SteamID3 / 2
} else {
    $Y = 1
    $Z = ($SteamID3 - 1) / 2
}
$SteamID64 = '7656119' + (($Z * 2) + (7960265728 + $Y))
$steamUserSummary = Get-SteamPlayerSummary -SteamID64 $SteamID64

##################################################################################################################
# MAIN SEEDING LOOP
##################################################################################################################

if($verbose -eq 1){
    Write-Host "Running Main Loop..."
}
do {
    Write-Host ""
    Write-Host (timestamp)("Checking for servers best suited for seeding.") -ForegroundColor Black -BackgroundColor White
    Write-Host ""
    $retry = 0
    
    if(-not ($serverSorted -eq $null)){
        $serverSorted = [ordered]@{}
        $serverList = [ordered]@{}
    }

    do {
        $error = 0
        #Loop through server list from the web and capture current population
        foreach ($server in $serversFromWeb){
            $IP = $server.Split(':')
            $gameInfo = Get-SteamServerInfo -IPAddress $IP[0] -Port $IP[1] -Timeout 10000 -ErrorAction SilentlyContinue
            if($gameInfo.Visibility -eq "Private"){
                Write-Host -ForegroundColor DarkGray (timestamp)($gameInfo.ServerName.ToString() + " is locked.") 
                if($verbose -eq 1){
                    Write-Host "LOCKED SERVER FOUND"
                }
            }
            #Desired servers
            elseif(($null -ne $gameInfo) -and ($gameInfo.Players -le $popGoal)){
                Write-Host -ForegroundColor Yellow (timestamp)($gameInfo.ServerName.ToString() + " needs seeding and has $($gameInfo.Players.ToString()) Soliders.")
                $serverList.Add($server, ($gameInfo.Players))
            }
            elseif($gameInfo.Players -gt $popGoal){
                Write-Host -ForegroundColor Green (timestamp)($gameInfo.ServerName.ToString() + " is already seeded with $($gameInfo.Players.ToString()) Soliders.")
            }
            else{
                Write-Host -ForegroundColor Red (timestamp) "$IP did not respond... Map Change? Crashed server? API failure?"
                $error = 1
            }
            Start-Sleep -Milliseconds 500
        }
        $retry = $retry + 1
        
        if($error -eq 1) {
            Write-Host -ForegroundColor Red (timestamp) "APFailures Detected. Retry $($retry) of 3"
            Start-Sleep -Seconds 10
        }
        
    } while($retry -le 2 -and $error -eq 1)
    
    $retry = 0

    #Sort List
    $serverSorted = ($serverList.getenumerator() | Sort-Object -Property Value -Descending)

    ### Pick a server to seed
    $serverToSeed = ""
    if($serverSorted -eq $null){
        Write-Host (timestamp) "There doesn't seem to be any servers in need of seeding!" -BackgroundColor White -ForegroundColor Black
        $continue = 0       
        
        if(($closeGame -eq 1) -and ($setting.superSeeder -eq 1)){
            Stop-Process -Name 'HLL-Win64-Shipping' -Force -erroraction 'silentlycontinue'
            Start-Sleep -Seconds 5
        }
    }
    else {
        #Find all servers with the same Player Count
        $serversWithSamePlayerCount = @()
        
        foreach( $item in $serverSorted) {
            if ($item.Value -eq $serverSorted[0].Value) {
                $serversWithSamePlayerCount += $item.Name
            }
            else {
                break;
            }
        }
 
        if ($serversWithSamePlayerCount.count -eq 1) {
            #If there is only one server with the max user count
            #we are done and can pick the top server
            $serverToSeed = $serverSorted[0].Name 
        }
        else {
            #If there are several servers with the same player count
            #Pick by priorty of servers from the web.
            $found = $false
            foreach($serverFromWeb in $serversFromWeb) {
                foreach($serverWithSamePlayerCount in $serversWithSamePlayerCount) {
                    if ($serverWithSamePlayerCount -eq $serverFromWeb) {
                        $serverToSeed = $serverWithSamePlayerCount
                        $found = $true
                        break;
                    }
                }
                if ($found -eq $true) {
                    break;
                }
            }
        }
        
        ### The server to seed has been picked        
        $continue = 1   
        $lastCheckForBetterServer=(GET-DATE)
        
        if( $currentlySeeding -eq $serverToSeed) {
            Write-Host "Already Seeding the correct server" -ForegroundColor Green
        } else {
            $IP = $serverToSeed.split(":")
            $gameInfo = Get-SteamServerInfo -IPAddress $IP[0] -Port $IP[1] -Timeout 10000
            Write-Host ""
            Write-Host (timestamp) "$($gameInfo.ServerName.ToString()) selected for seeding!" -ForegroundColor Blue

            $currentlySeeding = $serverToSeed
            $steamConnect = 'steam://connect/' + $gameInfo.IPAddress + ':' + $gameInfo.Port
            
            Start-Sleep -Milliseconds 100

            Start-Process -FilePath "$($steamDir.SteamExe)" -Wait -ArgumentList $steamConnect
            #Waits for splash and game window to appear, moves to another desktop env.

            $timeout = 0
            do{
                Start-Sleep -Milliseconds 100
                $timeout = $timeout + 1
                if ((Find-WindowHandle "EAC Launcher" -erroraction 'SilentlyContinue') -gt 0){
                    Get-Desktop ((Get-DesktopCount)-1) | Move-Window (Find-WindowHandle "EAC Launcher") -erroraction 'silentlycontinue' | Out-Null
                    if($verbose -eq 1){
                    Write-Host "SPLASH FOUND"
                    }
                }
            }while(-not (($timeout -gt 100) -or ((Find-WindowHandle "EAC Launcher") -gt 0) -or (Get-Process -Name 'HLL-Win64-Shipping' -ErrorAction SilentlyContinue)))
            $timeout = 0
            do{
                Start-Sleep -Milliseconds 100
                $timeout = $timeout + 1
                $location = Find-WindowHandle "Hell Let Loose" -ErrorAction 'SilentlyContinue' | Get-DesktopFromWindow -ErrorAction 'SilentlyContinue' | Get-DesktopName -ErrorAction 'SilentlyContinue'
                $currentEnv = Get-CurrentDesktop -erroraction 'SilentlyContinue' | Get-DesktopIndex -ErrorAction 'SilentlyContinue'
                $windowIndex = Find-WindowHandle "Hell Let Loose" -erroraction 'SilentlyContinue' | Get-DesktopFromWindow -ErrorAction 'SilentlyContinue' | Get-DesktopIndex -ErrorAction 'SilentlyContinue'
                $focused = Find-WindowHandle "Hell Let Loose" -erroraction 'SilentlyContinue' | Test-Window -erroraction 'silentlycontinue'
                if (($location -ne 'seeding')){
                    Get-Desktop ((Get-DesktopCount)-1) -erroraction 'SilentlyContinue' | Move-Window (Find-WindowHandle "Hell Let Loose") -ErrorAction 'SilentlyContinue' | Out-Null
                    Start-Sleep -Milliseconds 100
                    Switch-Desktop ($currentEnv) -erroraction 'SilentlyContinue'
                    if($verbose -eq 1){
                        Write-Host "GAME FOUND"
                    }
                }
            }while((-not ($timeout -gt 300)) -or ($location -ne 'seeding'))
            
            Start-Sleep -Seconds $launchSleep
            $SeedStart=(GET-DATE)
        }
        do {
            $IP = $currentlySeeding.Split(':')
            $gameInfo = Get-SteamServerInfo -IPAddress $IP[0] -Port $IP[1] -ErrorAction 'SilentlyContinue'
            $steamUserSummary = Get-SteamPlayerSummary -SteamID64 $SteamID64
            if(-not (timeframe)){
                Write-Host "The scheduler is stopping the seeding." -BackgroundColor Red
                if($verbose -eq 1){
                    Write-Host "Scheduler stopped seed loop"
                }
                break
            }
            elseif($steamUserSummary.Contains('gameserverip') -or $steamUserSummary.Contains('"personastate":0')){
                if($gameInfo -ne $null){
                    $SeedCurrent=(GET-DATE)
                    $since = NEW-TIMESPAN –Start $SeedStart –End $SeedCurrent
                    $sinceStamp = "[$([math]::Round($since.TotalMinutes))m]"
                    Write-Host (timestamp)(&{If($setting.sincestamp) {($sinceStamp)}}) "$($gameInfo.Players.ToString()) soldiers on $($gameInfo.ServerName)" -ForegroundColor Blue
                    if($steamUserSummary.Contains('"personastate":0')){
                        Write-Host "Unable to check status of your client, you seem to be offline on steam friends." -ForegroundColor DarkYellow
                    }
                }
                else{
                    Write-Host -ForegroundColor Yellow (timestamp) 'API ERROR : Failed to get Current Player Count, but you probably are still on the server fighting the good fight.'
                    if($steamUserSummary.Contains('"personastate":0')){
                        Write-Host -ForegroundColor Yellow "Unable to check status of your client, you seem to be offline on steam friends." -ForegroundColor DarkYellow
                    }
                }
            } 
            else {
                if ($null -ne $(Get-Process -Name 'HLL-Win64-Shipping' -ErrorAction 'SilentlyContinue')){
                    if($retry -lt 2){
                        $retry = $retry + 1
                        Start-Process -FilePath "$($steamDir.SteamExe)" -Wait -ArgumentList $steamConnect
                        Write-Host -ForegroundColor Yellow (timestamp)("Attempting to Join/Rejoin.")
                    }
                    else {
                        Write-Host -ForegroundColor Red (timestamp)("Unable to join game. Rebooting game.")
                        Stop-Process -Name 'HLL-Win64-Shipping'
                        break
                    }
                }
                else {
                    Write-Host -ForegroundColor Red (timestamp)("Game not found, exiting.")
                    Exit
                }
            }
            
            if($gameInfo.Players -gt $popGoal) {
                continue
            }
            
            Start-Sleep -Seconds $loopSleep
            
            #Check if its time to check the server statuses
            $currentTime=(GET-DATE)
            $since = NEW-TIMESPAN –Start $lastCheckForBetterServer –End $currentTime
            $sinceStamp = [math]::Round($since.TotalMinutes)
                        
        } until ($gameInfo.Players -gt $popGoal -or $sinceStamp -gt $checkOtherServersIntervalMinutes)
        
        if($gameInfo.Players -gt $popGoal){
            Write-Host (timestamp) "Server is seeded with" ($gameInfo.Players.ToString()) "soldiers. Recon will scout for another server to seed." -ForegroundColor Green
            continue
        }
    }

    if($setting.superSeeder -eq 1){
        Start-Sleep -Seconds $loopSleep
    }
} while (($setting.superSeeder -eq 1 -or $continue -eq 1) -and (timeframe -eq 1))

#EXIT TASKS
if($waitForInput -eq 1){
    Write-Host -NoNewLine `n 'Done. Press any key to continue...'`n
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}