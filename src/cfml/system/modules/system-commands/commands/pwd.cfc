/**
 * Output the current working directory of the shell.  This can be changed by using the "cd" command.
* .
* {code:bash}
* pwd
* {code}
 * 
 **/
component extends="commandbox.system.BaseCommand" {

	function run()  {
		return getCWD();
	}

}