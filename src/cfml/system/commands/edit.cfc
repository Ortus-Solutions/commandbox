/**
 * Open a file in the native OS application in order to edit it. If you pass in a 
 * folder, it will try to open the folder in an explorer or finder window.
 * .
 * {code:bash}
 * edit index.cfm
 * open myApp/
 * {code}
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="open" excludeFromHelp=false {

	/**
	 * @file.hint File to open natively, or Folder to open in an explorer window.
 	 **/
	function run( required file )  {
		
		// Make file canonical and absolute
		arguments.file = fileSystemUtil.resolvePath( arguments.file );

		if( !fileExists( arguments.file ) AND !directoryExists( arguments.file ) ){
			return error( "File: #arguments.file# does not exist, cannot open it!" );
		}

		if( fileSystemUtil.openNatively( arguments.file ) ){
			print.line( "Resource Opened!" );
		} else {
			error( "Unsupported OS, cannot open file/directory" );
		};
	}

}