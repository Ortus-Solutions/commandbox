/**
 * Runs a server script, by name.  Scripts are stored in server.json.
 * .
 * {code:bash}
 * server run-script myScript
 * {code}
 * .
 * Positional parameters can be passed and will be available as environment variables inside the script as ${1}, ${2}, etc
 * .
 * {code:bash}
 * server run-script myScript param1 param2
 * {code}
 * .
 * Named parameters can be passed and will be available as environment variables inside the script as ${name1}, ${name2}, etc
 * Note in this case, ALL parameters much be named including the scriptName param to the command.
 * .
 * {code:bash}
 * server run-script scriptName=myScript name1=value1 name2=value2
 * {code}
  **/
component {

	property name="serverService" inject="ServerService";

	/**
	 * @scriptName Name of the script to run
	 * @scriptName.optionsUDF scriptNameComplete
	 * @name.hint the short name of the server
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint web root for the server
	 * @serverConfigFile The path to the server's JSON file.
	 **/
	function run( 
		required string scriptname,
		string name,
		string directory,
		string serverConfigFile ){

		if( !isNull( arguments.directory ) ) {
			arguments.directory = resolvePath( arguments.directory );
		}
		if( !isNull( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = resolvePath( arguments.serverConfigFile );
		}
		var serverDetails = serverService.resolveServerDetails( arguments );
		
		// package check
		if( serverDetails.serverIsNew ) {
			error( "No servers found." );
		}

		// Add any additional arguments as env vars for the script to access
		arguments
			.filter( ( k, v ) => !'scriptName,name,directory,serverConfigFile'.listFindNoCase( k ) )
			.each( ( k, v ) => {
				// Decrement positional params so they start at 1
				if( isNumeric( k ) && k > 4 ) {
					k -= 4;
				}
				systemSettings.setSystemSetting( k, v );
			} );

		serverService.runScript( scriptName=arguments.scriptName, ignoreMissing=false, interceptData={ serverJSON : serverDetails.serverJSON } );

	}

	function scriptNameComplete( string paramSoFar, struct passedNamedParameters ) {
		
		if( !isNull( passedNamedParameters.directory ) ) {
			passedNamedParameters.directory = resolvePath( passedNamedParameters.directory );
		}
		if( !isNull( passedNamedParameters.serverConfigFile ) ) {
			passedNamedParameters.serverConfigFile = resolvePath( passedNamedParameters.serverConfigFile );
		}
		
		var serverDetails = serverService.resolveServerDetails( passedNamedParameters );
		var results = [];
		// package check
		if( !serverDetails.serverIsNew ) {
			results = ( serverDetails.serverJSON.scripts ?: {} ).keyArray();
		}
		return ( serverService.getDefaultServerJSON().scripts ?: {} ).keyArray().append( results, true );
	}
	
	/**
	* Complete server names
	*/
	function serverNameComplete() {
		return serverService.serverNameComplete();
	}

}
