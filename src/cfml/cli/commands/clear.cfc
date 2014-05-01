/**
 * Clear the output on the screen
 *
 * clear
 *
 **/
component persistent="false" extends="cli.BaseCommand" aliases="cls" {

	function run()  {
		shell.clearScreen();
	}


}