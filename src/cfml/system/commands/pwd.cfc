/**
 * Print the current working directory
 * 
 * pwd
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	function run()  {
		return shell.pwd();
	}

}