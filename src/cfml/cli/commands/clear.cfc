/**
 * Clear the output on the screen
 *
 * clear
 *
 **/
component persistent="false" extends="cli.BaseCommand" aliases="cls" excludeFromHelp=false {

	function run()  {
		shell.clearScreen();
	}


}