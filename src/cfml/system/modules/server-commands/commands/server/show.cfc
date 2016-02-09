/**
 * View proprties set in server.json for this server.  Command must be executed from the web root
 * directory of the server where server.json lives.  Call with no parameters to view the entire server.json
 * .
 * Outputs port
 * {code:bash}
 * server show port
 * {code}
 * .
 * Nested attributes may be accessed by specifying dot-delimited names or using array notation.
 * If the accessed property is a complex value, the JSON representation will be displayed
 * .
 * {code:bash}
 * server show key1.key2
 * {code}
 * .
 * {code:bash}
 * server show aliases[2]
 * {code}
 * 
 **/
component {
	
	property name="ServerService" inject="ServerService";
	property name="JSONService" inject="JSONService";
	
	/**
	 * @property.hint The name of the property to show.  Can nested to get "deep" properties
	 * @property.optionsUDF completeProperty
	 **/
	function run( string property='' ) {		
		var directory = getCWD();
						
		// Read without defaulted values
		var serverJSON = ServerService.readServerJSON( directory );

		try {
			
			var propertyValue = JSONService.show( serverJSON, arguments.property );
			
			if( isSimpleValue( propertyValue ) ) {
				print.line( propertyValue );
			} else {
				print.line( formatterUtil.formatJson( propertyValue ) );			
			}
		
		} catch( JSONException var e ) {
			error( e.message );
		} catch( any var e ) {
			rethrow;
		}

	}

	// Dynamic completion for property name based on contents of box.json
	function completeProperty() {
		return ServerService.completeProperty( getCWD() );				
	}
}