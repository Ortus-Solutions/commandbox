/**
 * This command will try to open the file in the native OS application in order to edit
 * 
 * edit index.cfm
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="open" excludeFromHelp=false {

	/**
	 * @file.hint File to edit
 	 **/
	function run( required file )  {
		
		// Make file canonical and absolute
		arguments.file = fileSystemUtil.resolvePath( arguments.file );

		if( !fileExists( arguments.file ) ){
			return error( "File: #arguments.file# does not exist, cannot open it!" );
		}

		if( fileSystemUtil.editFile( arguments.file ) ){
			print.line( "File opened!" );
		} else {
			error( "Unsupported OS, cannot open file" );
		};
	}

}