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
		variables.functionList = getFunctionList()
			.keyArray()
			// Add in member function versions of functions
			.reduce( function( orig, i ) {
				orig.append( i );				
				if( reFind( 'array|struct|query|image|spreadsheet|XML', i ) ) {
					orig.append( i.reReplaceNoCase( '(array|struct|query|image|spreadsheet|XML)(.+)', '\2' ) );
				}
				return orig;
			}, [] )
			// Sort function names longest to shortest
			.sort( function(a,b){
				if( a.len() > b.len() ) return -1;
				if( a.len() < b.len() ) return 1;
				return 0; 
			} );
		
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
			'in'
		];
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
		for( var func in functionList ) {
			// Find function names that are at the line start or prepended with a space, curly, or period and ending with an opening paren
			buffer = reReplaceNoCase( buffer, '(^|[ \.\{\}])(#func#)(\()', '\1' & print.boldCyan( '\2' ) & '\3', 'all' );
		}
		
		// highight reserved words
		for( var reservedWord in reservedWords ) {
			// Find keywords, bookended by a space, curly, paren, or semicolon. Or, of course, the start/end of the line
			buffer = reReplaceNoCase( buffer, '(^|[ \{\}\(])(#reservedWord#)($|[ ;\(\)\{\}])', '\1' & print.boldCyan( '\2' ) & '\3', 'all' );
		}
		
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
				buffer &= print.boldcyan( startChar );
				
				// Optional text between matching chars
				if( pos < originalBuffer.len()-1 ) {
					buffer &= originalBuffer.mid( pos+1, originalBuffer.len()-pos-1 );
				}
				// Ending char
				buffer &= print.boldcyan( endChar );
			}
		}

		return createObject("java","org.jline.utils.AttributedString").fromAnsi( buffer );	
	}
	
}