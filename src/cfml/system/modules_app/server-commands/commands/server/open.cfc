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
 *  * .
 * Open server administrator in browser
 * {code:bash}
 * server open --admin
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
	* @admin Open server administrator
	* @webAdmin Open web administrator
	* @webRoot Open web root in native file browser
	* @serverRoot Open server root in native file browser
	**/
	function run(
		URI="/",
		string name,
		string directory,
		string serverConfigFile,
		string browser = "",
		boolean admin = false,
		boolean webAdmin = false,
		boolean webRoot = false,
		boolean serverRoot = false
		){
		var argumentCount = 0;
		if ( arguments.URI != '/' ) {
			argumentCount++;
		}
		for ( var arg in ['admin','webAdmin','webRoot','serverRoot'] ) {
			if ( arguments[arg] ) {
				argumentCount++;
			}
		};
		if ( argumentCount > 1 ) {
			error ( "Oh my chickens! That's a lot to ask of me.  Please enter a URI or select one of the preset destinations (admin, webAdmin, webRoot, or serverRoot." );
		}
		if( !isNull( arguments.directory ) ) {
			arguments.directory = resolvePath( arguments.directory );
		}
		if( !isNull( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = resolvePath( arguments.serverConfigFile );
		}
		var serverDetails = serverService.resolveServerDetails( arguments );
		var serverInfo = serverDetails.serverInfo;

		if( serverDetails.serverIsNew ){
			print.boldRedLine( "No servers found." );
		} else {
			if ( arguments.webRoot ) {
				if ( fileSystemUtil.openNatively(serverInfo.appFileSystemPath) ) {
					print.line( "Web Root Opened." );
				} else {
					error ( "Unsupported OS, cannot open path." );
				}
				return;
			}
			if ( arguments.serverRoot ) {
				if ( fileSystemUtil.openNatively(serverInfo.serverHomeDirectory) ) {
					print.line( "Server Root Opened." );
				} else {
					error ( "Unsupported OS, cannot open path." );
				}
				return;
			}
			if ( arguments.admin ) {
				arguments.URI = serverInfo.cfengine.contains('lucee') ? '/lucee/admin/server.cfm' : arguments.URI;
				arguments.URI = serverInfo.cfengine.contains('railo') ? '/railo-context/admin/server.cfm' : arguments.URI;
				arguments.URI = serverInfo.cfengine.contains('adobe') ? '/CFIDE/administrator/enter.cfm' : arguments.URI;
			}
			if ( arguments.webAdmin ) {
				arguments.URI = serverInfo.cfengine.contains('lucee') ? '/lucee/admin/web.cfm' : arguments.URI;
				arguments.URI = serverInfo.cfengine.contains('railo') ? '/railo-context/admin/web.cfm' : arguments.URI;
				arguments.URI = serverInfo.cfengine.contains('adobe') ? '/CFIDE/administrator/enter.cfm' : arguments.URI;
			}
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
