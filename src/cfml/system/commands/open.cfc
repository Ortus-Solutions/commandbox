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
		
		// Make file canonical and absolute
		arguments.file = fileSystemUtil.resolvePath( arguments.file );
		
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