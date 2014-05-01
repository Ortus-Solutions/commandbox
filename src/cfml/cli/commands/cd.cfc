/**
 * The command will change the current working directory
 *
 * cd /tests
 *
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @directory.hint The directory to change to
	 **/
	function run( directory="" )  {
		return shell.cd( directory );
	}


}