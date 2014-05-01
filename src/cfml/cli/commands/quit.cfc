/**
* Exits out of the shell.
*
* quit
*
**/
component extends="cli.BaseCommand" aliases="exit,q,e" {

	function run()  {
		shell.exit();
	}

	
}