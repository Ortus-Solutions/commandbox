/**
 * Remove a property out of the server.json for this server.  Command must be executed from the web root
 * directory of the server where server.json lives.
 * Nested attributes may be set by specifying dot-delimited names or using array notation.
 * .
 * {code:bash}
 * server clear port
 * {code}
 * .
 **/
component {
	
	property name="serverService" inject="ServerService";
	property name="JSONService" inject="JSONService"; 
	
	/**  
	 * @property.hint Name of the property to clear 
	 * @property.optionsUDF completeProperty
	 **/
	function run( required string property ) {
		var directory = getCWD();
				
		var serverJSON = ServerService.readServerJSON( directory );
				
		try {
			JSONService.clear( serverJSON, arguments.property );
		} catch( JSONException var e ) {
			error( e.message );
		} catch( any var e ) {
			rethrow;
		}		
		
		print.greenLine( 'Removed #arguments.property#' );
				
		// Write the file back out.
		ServerService.saveServerJSON( directory, serverJSON );
			
	}

	// Dynamic completion for property name based on contents of server.json
	function completeProperty() {
		return serverService.completeProperty( getCWD() );				
	}
	
}