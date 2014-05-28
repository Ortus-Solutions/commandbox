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
		
		if( left( arguments.file, 1 ) != "/" ){
			arguments.file = shell.pwd() & "/" & arguments.file;
		}

		return fileRead( arguments.file );
	}

}