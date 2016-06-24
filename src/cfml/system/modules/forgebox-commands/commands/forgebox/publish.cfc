/**
 * Publishes a package with the ForgeBox endpoint.  This command is a passthrough for the generic "endpoint publish" command.
 * .
 * {code:bash}
 * forgebox publish
 * {code}
 **/
component aliases="publish" {
	
	/**  
	* @directory The directory to publish
	**/
	function run( 
		string directory='' 
	){		
	
		// Default the endpointName
		arguments.endpointName = 'forgebox';
		
		// Defer to the generic command
		command( 'endpoint publish' )
			.params( argumentCollection=arguments )
			.run();
				
	}

}