/**
* Exits out of the shell.  If the CommandBox binary was executed directly, the shell will close.  If the 
* CommandBox binary was run from your OS's native shell, you will be returned there.
* .
* {code:bash}
* exit
* {code}
* .
* Please note, any embedded servers started during your session will continue to run as they are in a separate
* process.  Use the icon in your OS's command tray to interact with the servers, or start CommandBox back up
* at a later time and "cd" to the root folder of the server.
*
**/
component aliases="exit,q,e" {

	function run()  {
		shell.exit();
	}
	
}