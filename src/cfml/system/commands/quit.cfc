/**
* Exits out of the shell.
*
* quit
*
**/
component extends="commandbox.system.BaseCommand" aliases="exit,q,e" excludeFromHelp=false {

	function run()  {
		shell.exit();
	}
	
}