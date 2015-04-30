/**
 * Stream editor command for manipulating text one line at a time.  Sed is similar to the
 * many Unix implementations, but only supports the "s" command (substitute) currently.
 * Pass or pipe the text to process or a filename along with the --file flag.
 * .
 * {code:bash}
 * sed "hello world" s/hello/goodbye/
 * Outputs: "goodbye world"
 * {code}
 * .
 * The substitute command syntax is "s/replaceMe/withMe/" where "s" is the command,
 * "replaceMe" is a CFML regular expression, and "withMe" is a replacement expression.
 * .
 * Supported pattern flags are "g" (global) which replaces all instances per line, and
 * "i" (ignore case) which makes the replacement case-insensitive.
 * .
 * {code:bash}
 * echo "one hundred and one" | sed s/ONE/two/gi
 * Outputs: "two hundred and two"
 * {code}
 * .
 * All other regex rules follow what is implemented in REReplace() CFML function.
 * .
 * The delimiter in the subsdtitute command does not have to be "/".  Whatever character
 * that immediatley follows the "s" will be used.  This can be useful where the regex
 * and/or replacement text contain a "/".  
 * .
 * This example uses a tilde (~) as the delimiter.  It reads a file, replaces all instances
 * of a given file path, and writes the file back out.
 * .
 * {code:bash}
 * sed --file config.cfm s~/var/www/~/sites/wwwroot/~i > config.cfm
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	// DI Properties
	property name='parser' 	inject='Parser';
	
	/**
	 * @inputOrFile.hint The text to process, or a file name to read with --file
	 * @commands.hint The command to perform on the input text.  Ex: s/replaceMe/withMe/g
	 * @file.hint Specifiy true to treat the input as a file path to read.
 	 **/
	function run(
		required string inputOrFile,
		required string commands,
		boolean file=false
		)  {
		
		// Treat input as a file path
		if( arguments.file ) {
			arguments.inputOrFile = runCommand( command="cat '#parser.escapeArg( arguments.inputOrFile )#'", returnOutput=true );			
		}
		
		// Turn output into an array, breaking on carriage returns
		var inputLines = listToArray( arguments.inputOrFile, CR );
		arguments.commands = trim( arguments.commands );
		
		// Only support a single command right now
		if( left( arguments.commands, 1 ) == 's' ) {
			substitute( inputLines, right( arguments.commands, len( arguments.commands ) -1 ) );
		} else {
			return error( 'Unknown command: [#arguments.commands#].  Type "sed help" for assistance.' );
		}
		
	}

	private function substitute( inputLines, command ) {
		var commandParts = parseCommandParts( arguments.command );
		if( hasError() ) { return; }
		var flags = parseFlags( commandParts.flags );
		
		try {
			
			// Loop over content
			for( var line in inputLines ) {
				if( flags.caseInsensitive ) {
					line = REReplaceNoCase( line, commandParts.regex, commandParts.replacement, ( flags.global ? 'all' : 'one' ) );
				} else {
					line = REReplace( line, commandParts.regex, commandParts.replacement, ( flags.global ? 'all' : 'one' ) );
				}
					
				print.line( line );
				
			} // End loop over inputLines
				
		} catch ( any var e ) {
			// Any errors here are most likley from bad regex.  Control the "error" and 
			// include some additional debugging information.
			return error(
				e.message & CR &
				'Regex: ' & commandParts.regex & CR &
				'Replacement: ' & commandParts.replacement
			);
		}
		
	}

	private function parseCommandParts( command ) {
		var str = trim( arguments.command );
		// The next char is the delimiter.  (doesn't have to be "/")
		var delimiter = left( str, 1 );
		str = right( str, len( str ) -1 );
		
	    var strLen = str.length();
		var isEscaped = false;
		var char = '';
		var phase = 1;
		
		var commandParts = {
			regex = '',
			replacement = '',
			flags = ''
		};
		
		// closure to help building up each part
		var appendStr = function() {
			// phase 1 is the regex
			if( phase == 1 ) { commandParts.regex &= char; }
			// phrase 2 is the replacement text
			else if( phase == 2 ) { commandParts.replacement &= char; }
			// everything else is the flags
			else { commandParts.flags &= char; }
		};
		
		// Not using list manipulation since the list delimiter is variable
		// AND can appear escaped with a backslash in the actual values.
		for (var i=0; i<strLen; i++) {
			char = str.substring(i,i+1);
			
			// If previous char was an escape, append no questions asked.
			if( isEscaped ) {
				isEscaped = false;
				appendStr();
				continue;
			}
			
			// If this is an escape, append and continue.
			if( char == '\' ) {
				isEscaped = true;
				// Peek ahead. If we're escaping a delimiter, eat the escape char
				if( strLen > i+1 && str.substring(i+1,i+2) != delimiter ) {
					appendStr();
				}
				continue;
			}
			
			// If we hit a delimiter, we've reached a new phase
			if( char == delimiter ) {
				phase++;
				continue;
			}
						
			appendStr();
		}
		
		if( phase < 3 ) {
			error( "Unterminated 's' command. We didn't find three delimiters of [#delimiter#]" );
		}
		
		return commandParts;
	}
	
	private function parseFlags( flags ) {
		return {
			global = ( arguments.flags contains 'g' ),
			caseInsensitive = ( arguments.flags contains 'i' )
		};
	}

}