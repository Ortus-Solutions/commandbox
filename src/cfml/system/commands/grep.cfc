/**
 * Search through string input and filter only matching lines.  Pipe input in and supply a regular expression.  
 * .
 * Find Brad's ForgeBox entries
 * {code:bash}
 * forgebox show | grep Brad
 * {code}
 * .
 * Find recent install commands
 * {code:bash}
 * history | grep install
 * {code}
 * .
 * Search log file for certain errors
 * {code:bash}
 * cat myLogFile.txt | grep "variable .* undefined"
 * {code}
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=true {
	
	/**
	 * @input.hint The piped input to be checked.
	 * @expression.hint A regular expression to match against each line of the input. Only matching lines will be output.
	 **/
	function run( input='', expression='' ) {
		// Turn output into an array, breaking on carriage returns
		var content = listToArray( arguments.input, CR ); 
								
		// Loop over content
		for( var line in content ) {
			
			// Does it match
			if( reFindNoCase( arguments.expression, line ) ) {
				// print it out
				print.line( line );				
			}
					
		}
	}

}