/**
 * Search through string input and filter duplicate lines.  Only unique results will be returned.
 * .
 * {code:bash}
 * cat names.txt | unique
 * {code}
 * .
 *  You can also get results with the occurance count preceeding each item
 * .
 * {code:bash}
 * cat names.txt | unique --count
 * {code}
 *
 **/
component {

	/**
	 * @input The piped input to be checked.
	 * @count Precede each line with the number of times that item appeared
	 **/
	function run( input='', count=false ) {
		// Turn output into an array, breaking on carriage returns
		var content = listToArray( arguments.input, chr(13)&chr(10) );
		var uniqueMap = {};

		// Loop over content
		for( var line in content ) {
			uniqueMap[ line ] = uniqueMap[ line ] ?: 0
			uniqueMap[ line ]++;
		}
		uniqueMap.each( (k,v)=>{
			print.line( (count ? v & ' ' : '' ) & k );
		} );
	}

}
