/**
 * Output the current working directory of the shell.  This can be changed by using the "cd" command.
* .
* {code:bash}
* pwd
* {code}
 * 
 **/
component {

	function run()  {
		return getCWD();
	}

}