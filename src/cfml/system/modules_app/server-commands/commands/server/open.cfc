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
		String serverConfigFile,
		String browser = ""
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
			openURL( thisURL, len( arguments.browser )? arguments.browser:configService.getSetting( 'preferredBrowser', '' ) );

		}
	}

	array function browserList( ) {
		if(fileSystemUtil.isWindows()){
			return ['firefox','chrome','opera','MicrosoftEdge','explorer'];
		}else if(fileSystemUtil.isMac()){
			return ['Firefox','GoogleChrome','MicrosoftEdge','Safari','Opera'];
		}else{
			return  ['firefox','chrome','opera','konqueror','epiphany','mozilla','netscape'];
		}
	}

	/**
	* Complete server names
	*/	
	function serverNameComplete() {
		return serverService
			.getServerNames()
			.map( ( i ) => {
				return { name : i, group : 'Server Names' };
			} );
	}

}
