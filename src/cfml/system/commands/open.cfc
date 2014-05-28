/**
 * This command will try to open the file in the native OS application for it.
 * 
 * open index.cfm
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @file.hint File to open
 	 **/
	function run( required file )  {
		
		if( left( arguments.file, 1 ) != "/" ){
			arguments.file = shell.pwd() & "/" & arguments.file;
		}

		if( !fileExists( arguments.file ) ){
			return error( "File: #arguments.file# does not exist, cannot open it!" );
		}

		if( fileSystemUtil.openFile( arguments.file ) ){
			return "File opened!";
		} else {
			error( "Unsopported OS" );
		};
	}

}