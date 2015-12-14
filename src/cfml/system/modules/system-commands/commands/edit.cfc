/**
 * Open a path in the native OS application in order to edit it. If you pass in a 
 * folder, it will try to open the folder in an explorer or finder window.
 * Passing no path, or an empty string will open the current working directory
 * .
 * {code:bash}
 * edit index.cfm
 * open myApp/
 * {code}
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="open" {

	/**
	 * @path.hint Path to open natively.
 	 **/
	function run( path='' )  {
		
		// Make path canonical and absolute
		arguments.path = fileSystemUtil.resolvePath( arguments.path );

		if( !fileExists( arguments.path ) AND !directoryExists( arguments.path ) ){
			return error( "Path: #arguments.path# does not exist, cannot open it!" );
		}

		if( fileSystemUtil.openNatively( arguments.path ) ){
			print.line( "Resource Opened!" );
		} else {
			error( "Unsupported OS, cannot open path." );
		};
	}

}