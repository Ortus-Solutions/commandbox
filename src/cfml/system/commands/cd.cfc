/**
 * The command will change the current working directory
 *
 * cd /tests
 *
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @directory.hint The directory to change to
	 **/
	function run( directory="" )  {
		// This will make each directory canonical and absolute		
		directory = fileSystemUtil.resolveDirectory( directory );
		
		return shell.cd( directory );
	}


}