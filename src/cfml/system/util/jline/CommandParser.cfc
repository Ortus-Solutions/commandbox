/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* CommandBox Command Line Parser and Tokenizer
*
*/
component {

	// DI
	property name='parser'	inject='parser';

	function parse( string line, numeric cursor, any context ) {
		// Call CommandBox parser to parse the line.
		var tokens = parser.tokenizeInput( line );

		// JLine expects there to be an empty string on the end of the array of the line ends with a space
		tokens = ( line.endsWith( ' ' ) ? tokens.append( '' ) : tokens );

		return createDynamicProxy(
			new ArgumentList( line, cursor, tokens, context ),
			[ 'org.jline.reader.ParsedLine', 'org.jline.reader.CompletingParsedLine' ]
		);
	}

}
