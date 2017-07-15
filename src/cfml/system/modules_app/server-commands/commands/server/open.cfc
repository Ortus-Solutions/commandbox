/**
 * This command will open the browser window to the current server root if started, else it is ignored.
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
 **/
component {

	// DI
	property name="serverService" inject="ServerService";

	/**
	* @URI An additional URI to go to when opening the server browser, else it just opens localhost:port
	 * @name.hint the short name of the server
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint web root for the server
	 * @serverConfigFile The path to the server's JSON file.
	**/
	function run(
		URI="/",
		string name,
		string directory,
		String serverConfigFile
		){
		if( !isNull( arguments.directory ) ) {
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		}
		if( !isNull( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = fileSystemUtil.resolvePath( arguments.serverConfigFile );
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
			openURL( thisURL );


		}
	}


	/**
	* Complete server names
	*/
	function serverNameComplete() {
		return serverService.getServerNames();
	}

}
