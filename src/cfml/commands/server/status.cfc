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
 * Or specifiy the web root directory.  If name and directory are both specified, name takes precedence.
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
component extends='commandbox.system.BaseCommand' aliases='status' excludeFromHelp=false {

	// DI
	property name='serverService' inject='ServerService';
	
	/**
	 * Show server status
	 *
	 * @name.hint 		Short name for the server
	 * @name.optionsUDF ServerNameComplete
	 * @directory.hint 	Web root for the server
	 * @showAll.hint 	show all server statuses
	 * @verbose.hint 	Show extra details
	 * @json 			Output the server data as json
	 **/
	function run(
		name='', 
		directory='',
		boolean showAll=false,
		boolean verbose=false,
		boolean JSON=false
	){
		// Get all server definitions
		var servers = serverService.getServers();

		// Display ALL as JSON?
		if( arguments.showALL && arguments.json ){
			print.line( 
				formatterUtil.formatJson( serializeJSON( servers ) )
			);
			return;
		}

		// scissors beats paper
		if( len( trim( arguments.name ) ) ) {
			arguments.directory = '';			
		} else {
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );			
		}

		// Map the server statuses to a color
		var statusColors = {
			running 	: 'green',
			starting 	: 'yellow',
			stopped 	: 'red'			
		};

		for( var thisKey in servers ){
			var thisServerInfo = servers[ thisKey ];

			// If this is a directory or a name match OR are we just showing everything
			if( thisServerInfo.webroot == arguments.directory
				|| thisServerInfo.name == arguments.name
				|| arguments.showAll 
			){
				
				// Null Checks, to guarnatee correct struct.
				structAppend( thisServerInfo, serverService.newServerInfoStruct(), false );
				
				// Are we doing JSON?
				if( arguments.json ){
					print.line( 
						formatterUtil.formatJson( serializeJSON( thisServerInfo ) )
					);
					continue;
				}

				print.line().boldText( thisServerInfo.name );
	
				var status = thisServerInfo.status;
				print.boldtext( ' (' )
					.bold( status, statusColors.keyExists( status ) ? statusColors[ status ] : 'yellow' )
					.bold( ')' );
	
				print.indentedLine( thisServerInfo.host & ':' & thisServerInfo.port & ' --> ' & thisServerInfo.webroot );
					 
				print.line();
				print.indentedLine( thisServerInfo.statusInfo.result );
					 
				if( arguments.verbose ) {
					
					print.indentedLine( trim( thisServerInfo.statusInfo.command ) );
					// Put each --arg or -arg on a new line
					var args = trim( replaceNoCase( thisServerInfo.statusInfo.arguments, ' -', cr & '-', 'all' ) );
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
		return serverService.getServerNames();
	}

}