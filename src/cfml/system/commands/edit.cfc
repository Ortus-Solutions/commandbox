/**
 * This command will try to open the file in the native OS application in order to edit
 * 
 * edit index.cfm
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @file.hint File to edit
 	 **/
	function run( required file )  {
		
		if( left( arguments.file, 1 ) != "/" ){
			arguments.file = shell.pwd() & "/" & arguments.file;
		}

		if( !fileExists( arguments.file ) ){
			return error( "File: #arguments.file# does not exist, cannot edit it!" );
		}

		if( fileSystemUtil.editFile( arguments.file ) ){
			return "File opened!";
		} else {
			error( "Unsupported OS, cannot edit file" );
		};
	}

}