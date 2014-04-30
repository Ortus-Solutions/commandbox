/**
 * Clear screen
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" {

	function run()  {
		shell.clearScreen();
	}


}