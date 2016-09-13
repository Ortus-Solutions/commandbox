/**
 *  Unpublishes a package from the ForgeBox endpoint.  This command is a passthrough for the generic "endpoint unpublish" command.
 * .
 * {code:bash}
 * forgebox unpublish
 * {code}
 **/
component aliases="unpublish" {
	
	/**  
	* @version The directory to publish
	* @directory The directory to publish
	* @force Skip the prompt
	**/
	function run( 
		string version='',
		string directory='',
		boolean force=false 
	){		
	
		// Default the endpointName
		arguments.endpointName = 'forgebox';
		
		// Defer to the generic command
		command( 'endpoint unpublish' )
			.params( argumentCollection=arguments )
			.run();
				
	}

}