/**
 * Show status of an embedded server.  Run command from the web root of the server.
 * .
 * {code:bash}
 * server status
 * {code}
 * .
 * Or specify a server name
 * .
 * {code:bash}
 * server status serverName
 * {code}
 * .
 * Or specify the web root directory.  If name and directory are both specified, name takes precedence.
 *
 * {code:bash}
 * server status directory=C:\path\to\server
 * {code}
 * .
 * Show all registered servers with the --showAll flag
 *
 * {code:bash}
 * server status --showAll
 * {code}
 * .
 * Get extra information about the server and how it was last started/stopped with the --verbose flag
 *
 * {code:bash}
 * server status --verbose
 * {code}
 * .
 **/
component aliases='status,server info' {

	// DI
	property name='serverService' inject='ServerService';

	/**
	 * Show server status
	 *
	 * @name.hint the short name of the server
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint web root for the server
	 * @serverConfigFile The path to the server's JSON file.
	 * @showAll.hint 	show all server statuses
	 * @verbose.hint 	Show extra details
	 * @json 			Output the server data as json
	 * @property		Name of a specific property to output. JSON default to true if this is used.
	 * @property.optionsUDF propertyComplete
	 **/
	function run(
		string name,
		string directory,
		String serverConfigFile,
		boolean showAll=false,
		boolean verbose=false,
		boolean JSON=false,
		string property=''	){
		// Get all server definitions
		var servers = serverService.getServers();

		// If you specify a property, JSON gets enabled.
		arguments.JSON = ( arguments.JSON || len( property ) );

		// Display ALL as JSON?
		if( arguments.showALL && arguments.json ){
			print.line(
				servers
			);
			return;
		}

		if( !isNull( arguments.directory ) ) {
			arguments.directory = resolvePath( arguments.directory );
		}
		if( !isNull( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = resolvePath( arguments.serverConfigFile );
		}
		var serverDetails = serverService.resolveServerDetails( arguments );
		var serverInfo = serverDetails.serverInfo;

		// Map the server statuses to a color
		var statusColors = {
			running 	: 'green',
			starting 	: 'yellow',
			stopped 	: 'red'
		};

		for( var thisKey in servers ){
			var thisServerInfo = servers[ thisKey ];

			// If this is a server  match OR are we just showing everything
			if( thisServerInfo.id == serverInfo.id || arguments.showAll ){

				// Null Checks, to guarantee correct struct.
				structAppend( thisServerInfo, serverService.newServerInfoStruct(), false );

				thisServerInfo.status = serverService.isServerRunning( thisServerInfo ) ? 'running' : 'stopped';
					
				// Are we doing JSON?
				if( arguments.json ){

					// Are we outputting a specific property
					if( len( arguments.property ) ) {

						// If the key doesn't exist, give a useful error
						if( !isDefined( 'thisServerInfo.#arguments.property#' ) ) {
							error( "The property [#arguments.property#] isn't defined in the JSON.", "Valid keys are: " & chr( 10 ) & "   - "  & thisServerInfo.keyList().lCase().listChangeDelims( chr( 10 ) & "   - " ) );
						}

						// Output a single property
						var thisValue = evaluate( 'thisServerInfo.#arguments.property#' );
						// Output simple values directly so they're useful
						if( isSimpleValue( thisValue ) ) {
							print.line( thisValue );
						// Format Complex values as JSON
						} else {
							print.line(
								thisValue
							);
						}

					} else {

						// Output the entire object
						print.line(
							thisServerInfo
						);

					}

					continue;
				}

				print.line().boldText( thisServerInfo.name );

				print.boldtext( ' (' )
					.bold( thisServerInfo.status, statusColors.keyExists( thisServerInfo.status ) ? statusColors[ thisServerInfo.status ] : 'yellow' )
					.bold( ')' );

				print.indentedLine( thisServerInfo.host & ':' & thisServerInfo.port & ' --> ' & thisServerInfo.webroot );
				if( len( serverInfo.engineName ) ) {
					print.indentedLine( 'CF Engine: ' & serverInfo.engineName & ' ' & serverInfo.engineVersion );
				}
				if( len( serverInfo.warPath ) ) {
					print.indentedLine( 'WAR Path: ' & serverInfo.warPath );
				}
				if( len( serverInfo.dateLastStarted ) ) {
					print.indentedLine( 'Last Started: ' & datetimeFormat( serverInfo.dateLastStarted ) );
				}
				print.line();
				print.indentedLine( 'Last status message: ' );
				print.indentedLine( thisServerInfo.statusInfo.result );

				if( arguments.verbose ) {

					print.indentedLine( 'ID: ' & thisServerInfo.id );

					print.line().indentedLine( 'Server Home: ' & thisServerInfo.serverHome );
					
					print.line().indentedLine( 'PID file used for "running" check: ' )
						.indentedIndentedLine( serverInfo.pidFile );
						
					if( fileExists( serverInfo.pidFile ) ){
						print.indentedIndentedLine( 'PID file exists.' );
						try {
							var serverPID = fileRead(serverInfo.pidFile);
							if( serverService.isProcessAlive( serverPID, true ) ) {
								print.indentedIndentedLine( 'PID [#serverPID#] is running' );
							} else {
								print.indentedIndentedLine( 'PID [#serverPID#] is NOT running' );
							}
						} catch( any var e ) {
							print.indentedIndentedText( 'Error checking if server PID was running: [' ).redText( e.message & ' ' & e.detail ).line( '] Server is assumed running.' );
						}						
					} else {
						print.indentedIndentedLine( 'PID file does not exist.  Server is assumed stopped.' );
					}
					

					print.line().indentedLine( 'Last Command: ' );
					// Put each --arg or -arg on a new line
					var args = trim( reReplaceNoCase( thisServerInfo.statusInfo.arguments, ' (-|"-)', cr & '\1', 'all' ) );
					print.indentedIndentedLine( args )
						.line();

				}
			} // End "filter" if
		}

		// No servers found, then do nothing
		if( structCount( servers ) eq 0 ){
			print.boldRedLine( 'No server configurations found!' );
		}
	}

	/**
	* AutoComplete server names
	*/
	function serverNameComplete() {
		return serverService.serverNameComplete();
	}

	/**
	* AutoComplete serverInfo properties
	*/
	function propertyComplete() {
		return serverService.newServerInfoStruct().keyArray();
	}

}
