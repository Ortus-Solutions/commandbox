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
	
		return createObject( 'java', 'org.jline.reader.impl.DefaultParser$ArgumentList' ).init(
			// Since this inner class is not a static reference, an instance of the parent class is required
			createObject( 'java', 'org.jline.reader.impl.DefaultParser' ).init(),
			// line - The unparsed line
			line,
			// words - The list of words
			tokens,
			// wordIndex - The index of the current word in the list of words
			max( tokens.len()-1, 0 ),
			// wordCursor - The cursor position within the current word
			( tokens.len() ? tokens.last().len() : 0 ),
			// cursor - The cursor position within the line
			cursor,
			// openingQuote - Not sure what this does.
			''
		);	
		
	}

}
