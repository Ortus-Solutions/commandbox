/**
 * This is the grep command. Pipe input into it and supply a regular expression to filter lines to output
 * 
 * forgebox show | grep Brad
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=true {
	
	/**
	 * @input.hint The piped input to be checked.
	 * @expression.hint A regular expression to match against each line of the input. Only matching line will be output.
	 **/
	function run( input='', expression='' ) {
		// Turn output into an array, breaking on carriage returns
		var content = listToArray( input, CR ); 
								
		// Loop over content
		for( var line in content ) {
			
			// Does it match
			if( reFindNoCase( expression, line ) ) {
				// print it out
				print.line( line );				
			}
					
		}
	}

}