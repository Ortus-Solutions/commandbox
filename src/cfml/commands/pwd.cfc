/**
 * Print the current working directory
 * 
 * pwd
 * 
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	function run()  {
		return shell.pwd();
	}



}