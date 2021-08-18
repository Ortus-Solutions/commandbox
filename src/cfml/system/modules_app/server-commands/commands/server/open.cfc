/**
 * Open the browser window to the current server root.  If not started it is ignored.
 * This command must be ran from the directory were the server was started.
 * .
 * {code:bash}
 * server open
 * {code}
 * .
 * Open a specific path with the URI parameter
 * {code:bash}
 * server open /tests/runner.cfm
 * {code}
 * .
 * Open a specific browser with the browser parameter
 * {code:bash}
 * server open URI=/admin browser=firefox
 * {code}
 **/
component {

	// DI
	property name="serverService" inject="ServerService";
	property name="fileSystemUtil" inject="FileSystem";
	/**
	* @URI An additional URI to go to when opening the server browser, else it just opens localhost:port
	* @URI.optionsFileComplete true
	* @name.hint the short name of the server
	* @name.optionsUDF serverNameComplete
	* @directory.hint web root for the server
	* @serverConfigFile The path to the server's JSON file.
	* @browser The browser to open the URI
	* @browser.optionsUDF browserList
	**/
	function run(
		URI="/",
		string name,
		string directory,
		string serverConfigFile,
		string browser = ""
		){
		if( !isNull( arguments.directory ) ) {
			arguments.directory = resolvePath( arguments.directory );
		}
		if( !isNull( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = resolvePath( arguments.serverConfigFile );
		}
		var serverDetails = serverService.resolveServerDetails( arguments );
		var serverInfo = serverDetails.serverInfo;

		if( serverDetails.serverIsNew ){
			print.boldRedLine( "No server configurations found so have no clue what to open buddy!" );
		} else {
			// myPath/file.cfm is normalized to /myMapth/file.cfm
			if( !arguments.URI.startsWith( '/' ) ) {
				arguments.URI = '/' & arguments.URI;
			}
			var thisURL = "#serverInfo.host#:#serverInfo.port##arguments.URI#";
			print.greenLine( "Opening...#thisURL#" );
			openURL( thisURL, arguments.browser );

		}
	}

	array function browserList( ) {
		return fileSystemUtil.browserList();
	}

	/**
	* Complete server names
	*/
	function serverNameComplete() {
		return serverService.serverNameComplete();
	}

}
