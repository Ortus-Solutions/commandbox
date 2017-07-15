/**
 * Clear any output on the terminal.
 * .
 * {code:bash}
 * clear
 * {code}
 *
 **/
component aliases="cls" {

	function run()  {
		shell.clearScreen();
	}

}
