========= STEP-BY-STEP ============
	Place files where you want them to live. (Recommendation for a folder in My Documents)
	Start the "Start.cmd" file.
	Follow the instructions in the console outputs.
	(Optional) Edit Settings file.
	
Running on startup :
	Right click the "Start.cmd" and create a shortcut.
	Place the shortcut to the "Start.cmd" inside the following folder.
	C:\Users\<Username>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup


========= Questions? Having trouble? =========

Q: How do I configure the settings?
A: Settings can be found in Documents/seedscript/.

Q: How to I stop the script?
A: Crtl+C the command window.

Q: Where did the game / script window go? All I see is stuff flashing then vanishing.
A: It moves itself onto its own virtual desktop called "Seeding". Access them with Win+Tab.

Q: I messed up my steamAPI entry, how do I re-enter it?
A: Either open Powershell from the start menu and type "Connect-SteamAPI" or for the script to prompt on launch again, remove the file found in C:\Users\<Username>\AppData\Roaming\SteamPS

Q: "ForbiddenAccess" "Verify your key= parameter"
A: Treat it as a messed up steamAPI entry, follow troubleshoot above.

Q: What do I use for my domain when I sign up for SteamAPI?
A: Its purely for reference, just type "localhost" if unsure.

Q: Something is still not working.
A: Edit the seed_tl.ps1 file and toggle the "$elevate =" to whichever the opposite it currently is, if that still doesn't work, Message @トミー(Tommy) in discord.