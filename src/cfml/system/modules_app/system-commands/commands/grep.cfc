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
component excludeFromHelp=true {

	/**
	 * @input.hint The piped input to be checked.
	 * @expression.hint A regular expression to match against each line of the input. Only matching lines will be output.
	 * @count.hint Return only a count of the matched rows
	 **/
	function run( input='', expression='', boolean count=false ) {
		// Turn output into an array, breaking on carriage returns
		var content = listToArray( arguments.input, chr(13)&chr(10) );
		var numMatches = 0;

		// Loop over content
		for( var line in content ) {

			// Does it match
			if( arguments.expression == '' || reFindNoCase( arguments.expression, line ) ) {
				if( count ) {
					numMatches++;
				} else {
					print.line( line );
				}
			}

		}

		if( count ) {
			print.line( numMatches );
		}
	}

}
