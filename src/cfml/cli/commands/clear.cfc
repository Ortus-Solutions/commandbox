/**
 * Clear screen
 **/
component persistent="false" extends="cli.BaseCommand" aliases="cls" {

	function run()  {
		shell.clearScreen();
	}


}