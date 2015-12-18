/**
 * I am a shortcut to run CFML functions via the REPL. I take the parameters that are passed
 * into this command and pass them along to the CFML function. 
 * .
 * {code:bash}
 * 
 * {code}
 * .
 **/
component{

	property name="formatterUtil" inject="Formatter";

	/**
	* @.hint 
	**/
	function run(
		required name
	){

		var functionText = arguments.name & '( ';
		
		// Additional param go into the function
		if( arrayLen( arguments ) > 1 ) {
			 
			// Positional params
			if( isNumeric( listGetAt( structKeyList( arguments ), 2 ) ) ) {
	
				var i = 1;
				while( ++i <= arrayLen( arguments ) ) {
					
					functionText &= ( i>2 ? ', ' : '' );
					
					// If this is a struct or array function, we have at least one param, and it's JSON, just pass it in as complex data.
					if( ( left( arguments.name, 5 ) == 'array' || left( arguments.name, 6 ) == 'struct' )
					    && i==2 && isJSON( arguments[ i ] ) ) {
						functionText &= '#arguments[ i ]#';
					} else {
						functionText &= '"#escapeArg( arguments[ i ] )#"';
					}
					
				} // end param loop

		
			// Named params
			} else {
				
				var i = 0;
				for( var param in arguments ) {
					if( param=='name' ) {
						continue; 
					}					
					i++;
					
					functionText &= ( i>1 ? ', ' : '' );					
					
					functionText &= '#param#="#escapeArg( arguments[ param ] )#"';
					
				} // end param loop

				
			}
					
			
		} // end additional params?
		
		functionText &= ' )';

		print.text(
			command( "repl" )
				.params( functionText )
				.run( returnOutput=true, echo=false )
		);
				
			
		try{
			
			
		
		} catch (any e) {
			error( '#e.message##CR##e.detail#' );
		}

	}

	private function escapeArg( required string arg ) {
		return replaceNoCase( arguments.arg, '"', '""', 'all' );
	}

}