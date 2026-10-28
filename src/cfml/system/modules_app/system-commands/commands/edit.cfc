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
component aliases="open" {

	/**
	 * @path.hint Path to open natively.
 	 **/
	function run( Globber path=globber( getCWD().left(-1) ) )  {

		path.apply( function( thisPath ) {

			if( fileSystemUtil.openNatively( thisPath ) ){
				print.text( "Resource Opened!" );
			} else {
				error( "Unsupported OS, cannot open path." );
			};

		} );

	}

}
