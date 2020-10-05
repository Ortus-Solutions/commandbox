/**
 * Open a browser to the passed URI.
 * .
 * Concatenate two files and output them to the screen
 * {code:bash}
 * browse localhost:8116
 * {code}
 *
 **/
component {

	/**
	 * @URI The URI to open as you would type it into your browser's address bar
	 * @browser The preferred browser to use for your URI
	 * @browser.optionsUDF browserList
 	 **/
	function run( required URI, browser='' )  {

		if( fileSystemUtil.openBrowser( arguments.URI, arguments.browser ) ){
			print.line( "Browser opened!" );
		} else {
			error( "Unsopported OS" );
		};
	}

	array function browserList() {
		return fileSystemUtil.browserList();
	}

}
