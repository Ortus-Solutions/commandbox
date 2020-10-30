/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
* I am a JLine highighter class that attempts to highlight the command portion of the input buffer
*/
component {

	// DI
	property name='print'			inject='print';
	property name='shell'			inject='provider:shell';

	function init() {

		variables.reservedWords = [
			'if',
			'else',
			'try',
			'catch',
			'var',
			'for',
			'default',
			'switch',
			'case',
			'continue',
			'import',
			'finally',
			'local',
			'interface',
			'true',
			'false',
			'return',
			'in',
			'function',
			'any'
		].toList( '|' );

		variables.sets = {
			')' : '(',
			'}' : '{',
			']' : '[',
			"'" : "'",
			'"' : '"'
		};
		return this;
	}

	function highlight( reader, buffer ) {

		// Highlight CF function names
		// Find text that is at the line start or prepended with a space, curly, or period and ending with an opening paren
		buffer = reReplaceNoCase( buffer, '(^|[ \-##\.\{\}\(\)])([^ \-##\.\{\}\(\)]*)(\()', '\1' & print.boldCyan( '\2' ) & '\3', 'all' );

		// highight reserved words
		buffer = reReplaceNoCase( buffer, '(^|[ \{\}\(])(#reservedWords#)($|[ ;\(\)\{\}])', '\1' & print.boldCyan( '\2' ) & '\3', 'all' );

		// If the last character was an ending } or ) or ] or " or ' then highlight it and the matching start character
		// This logic is pretty basic and doesn't account for escaped stuff.  If you want, please send a pull to improve it :)
		if( sets.keyExists( buffer.right( 1 ) ) ) {
			var endChar = buffer.right( 1 );
			var startChar = sets[ endChar ];
			var depth = 1;
			var pos = buffer.len()-1;
			// Work backwords over the string until we find a matching start char
			while( pos > 0 && depth > 0 ) {
				if( buffer.mid( pos, 1 ) == endChar && startChar != endChar ) {
					depth++;
				} else if( buffer.mid( pos, 1 ) == startChar ) {
					depth--;
				}
				if( depth == 0 ) {
					break;
				}
				pos--;
			}

			// If we found a matching start char
			if( pos > 0 ) {
				var originalBuffer = buffer;
				buffer = '';
				// Optional text before the start char
				if( pos > 1 ) {
					buffer = originalBuffer.mid( 1, pos-1 );
				}
				// The start char
				buffer &= print.boldRed( startChar );

				// Optional text between matching chars
				if( pos < originalBuffer.len()-1 ) {
					buffer &= originalBuffer.mid( pos+1, originalBuffer.len()-pos-1 );
				}
				// Ending char
				buffer &= print.boldRed( endChar );
			}
		}

		return createObject("java","org.jline.utils.AttributedString").fromAnsi( buffer );
	}

}