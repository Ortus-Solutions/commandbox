/**
 * Clear any output on the terminal.
 * .
 * {code}
 * clear
 * {code}
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="cls" excludeFromHelp=false {

	function run()  {
		shell.clearScreen();
	}

}