/**
* Exits out of the shell.
*
* quit
*
**/
component extends="cli.BaseCommand" aliases="exit,q,e" excludeFromHelp=false {

	function run()  {
		shell.exit();
	}

	
}