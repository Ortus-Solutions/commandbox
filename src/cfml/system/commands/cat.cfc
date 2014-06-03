/**
 * This command will read a file and display its contents to the console
 * 
 * cat box.json
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="type" excludeFromHelp=false {

	/**
	 * @file.hint File to view contents of
 	 **/
	function run( required file )  {
		
		// Make file canonical and absolute
		arguments.file = fileSystemUtil.resolvePath( arguments.file );

		return fileRead( arguments.file );
	}

}