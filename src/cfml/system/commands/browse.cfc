/**
 * This command will try to open a browser to the passed URI
 * 
 * browse localhost
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @URI.hint The URI to open
 	 **/
	function run( required URI )  {

		if( fileSystemUtil.openBrowser( arguments.URI ) ){
			return "Browser opened!";
		} else {
			error( "Unsopported OS" );
		};
	}

}