/**
* This commnd waits for the user to press a key to continue.  You could use this in a boxr recipe
* to pause execution so you can see the previous commands' output before the windows closes if 
* calling it from a shortcut to a native OS prompt that closes as soon as it's complete.
 * .
 * {code:bash}
 * pause
 * {code}
**/
component extends="commandbox.system.BaseCommand" excludeFromHelp=true {


	function run()  {
		waitForKey( 'Press any key to continue...' );
		print.line();		
	}


}