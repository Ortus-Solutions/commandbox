/**
 * Print the current working directory
 * 
 * pwd
 * 
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=false {

	function run()  {
		return shell.pwd();
	}



}