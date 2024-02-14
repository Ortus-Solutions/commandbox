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
		URI="",
		string name,
		string siteName='',
		string directory,
		string serverConfigFile,
		string browser = "",
		boolean admin = false,
		boolean webAdmin = false,
		boolean webRoot = false,
		boolean serverRoot = false
		){
		var argumentCount = 0;
		if ( arguments.URI != '' ) {
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
		var siteInfo = serverInfo;
		if( serverInfo.sites.len() > 1 ) {
			if( len( arguments.siteName ) ) {
				if( serverInfo.sites.keyExists( siteName ) ) {
					siteInfo = serverInfo.sites[ siteName ];
				} else {
					error( 'Site name [#siteName#] not found in server [#serverInfo.name#].' )
				}
			} else if( shell.isTerminalInteractive() ) {
				siteName = multiSelect( 'Which site would you like to open? ' )
					.options( serverInfo.sites.reduce( (sites,siteName,site)=>{
							sites.append( {
								display : '#siteName# (#site.webroot#)',
								value : siteName
							} ); return sites;
						}, [] ) )
					.required()
					.ask();
				siteInfo = serverInfo.sites[ siteName ];
			} else {
				error( 'Server [#serverInfo.name#] has more than one site. Please choose the one to open with the [siteName] parameter.' );
			}
		}

		if( serverDetails.serverIsNew ){
			print.boldRedLine( "No servers found." );
		} else {
			var serverJSON = serverService.readServerJSON( serverDetails.defaultServerConfigFile )
			// If no explicit browser was provided to this command, but the server.json has one, use that.
			if( !len( arguments.browser ) && len( serverJSON.preferredBrowser ?: '' ) ) {
				arguments.browser = serverJSON.preferredBrowser;
			}
			if( !len( arguments.browser ) && len( serverInfo.preferredBrowser ) ) {
				arguments.browser = serverInfo.preferredBrowser;
			}

			if ( arguments.webRoot ) {
				if ( fileSystemUtil.openNatively(siteInfo.webroot) ) {
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
			if( len( arguments.URI ) && !arguments.URI.startsWith( '/' ) ) {
				arguments.URI = '/' & arguments.URI;
			}
			if( arguments.URI == '' ) {
				var thisURL = "#siteInfo.openBrowserURL#";
			} else {
				var thisURL = "#siteInfo.defaultBaseURL##arguments.URI#";
			}
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
