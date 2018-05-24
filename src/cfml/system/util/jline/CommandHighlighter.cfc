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
	property name='CommandService'	inject='CommandService';
	property name='print'			inject='print';
	
	function init() {
		variables.functionList = getFunctionList();
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
		
		// Call CommandBox parser to parse the line.
		var commandChain = CommandService.resolveCommand( buffer );
		
		// For each command in the chain
		for( var command in commandChain ) {
			// Ignore blank lines
			if( command.commandString.len() ) {
				
				// Highlight the command portion of the line.
				var thisCommand = command.commandString.listChangeDelims( ' ', '.' );
				
				// Check if the user is typing something like 
				// server start help 
				// server start ?
				// help server start
				if( thisCommand.left( 4 ) == 'help' ) {
									
					// Highlight the ? or help at the end
					buffer = reReplaceNoCase( buffer, '(.*)(\?|help)([\s]*)$', '\1' & print.yellowBold( '\2' ) & '\3' );
					// Highlight the ? or help at the beginning
					buffer = reReplaceNoCase( buffer, '(\?|help)(.*)$', print.yellowBold( '\1' ) & '\2' );
					
					// See if the rest of the text they typed in resolves to a command or not
					var helloCommandChain = CommandService.resolveCommand( command.parameters.toList( ' ' ) );
					var helloCommand = helloCommandChain[1].commandstring.listChangeDelims( ' ', '.' );
					// If so, let's highlight the command part of it
					if( helloCommand.len() ) {						
						buffer = replaceNoCase( buffer, helloCommand, print.yellowBold( helloCommand ) );
						
					}
				// Check if the user is typing something like #now
				} else 	if( thisCommand.left( 4 ) == 'cfml' && command.parameters.len()
				&& variables.functionList.keyExists( command.parameters[ 1 ] ) ) {
					buffer = replaceNoCase( buffer, command.parameters[ 1 ], print.yellowBold( command.parameters[ 1 ] ) );
				// All other "normal" commands
				} else {
					// This won't highlight more than one instance of the same command like 
					// > echo foo | grep foo | grep bar
					// If we replace "all" the above will work, but the following will highlight the param as well:
					// > echo "echo"
					// Things like whitespace is normalized and escapes are processed, so I can't rebuild the exact original
					// buffer from the command chain so this work around is a "close enough" implementation for now.
					buffer = replaceNoCase( buffer, thisCommand, print.yellowBold( thisCommand ) );
				}
			}  
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