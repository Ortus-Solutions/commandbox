/**
 * Clear any output on the terminal.
 * .
 * {code:bash}
 * clear
 * {code}
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="cls" excludeFromHelp=false {

	function run()  {
		shell.clearScreen();
	}

}