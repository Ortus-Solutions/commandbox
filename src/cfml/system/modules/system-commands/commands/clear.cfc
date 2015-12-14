/**
 * Clear any output on the terminal.
 * .
 * {code:bash}
 * clear
 * {code}
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="cls" {

	function run()  {
		shell.clearScreen();
	}

}