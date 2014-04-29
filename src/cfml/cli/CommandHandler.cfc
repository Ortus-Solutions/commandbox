/**
 * Command handler
 * @author Denny Valliant
 **/
component output='false' persistent='false' {

	instance = {
		shell = '',
		commands = {},
		commandAliases = {},
		namespaceHelp = {},
		thisdir = getDirectoryFromPath(getMetadata(this).path),
		System = createObject('java', 'java.lang.System')
	};
	
	
	instance.rootCommandDirectory = instance.thisdir & '/commands';
	
	// Convenience value
	cr = instance.System.getProperty('line.separator');

	/**
	 * constructor
	 * @shell.hint shell this command handler is attached to
	 **/
	function init(required shell) {
		instance.shell = shell;
		reader = instance.shell.getReader();
        var completors = createObject('java','java.util.LinkedList');
		initCommands( instance.rootCommandDirectory, '' );
				
		var completor = createDynamicProxy(new Completor(this), ['jline.Completor']);
        reader.addCompletor(completor);
		return this;
	}

	/**
	 * initialize the commands. This will recursively call itself for subdirectories.
	 **/
	function initCommands( commandDirectory, commandPath ) {
		var varDirs = DirectoryList( path=commandDirectory, recurse=false, listInfo='query', sort='type desc, name asc' );
		
		for(var dir in varDirs){
			
			// For CFC files, process them as a command
			if( dir.type  == 'File' && listLast( dir.name, '.' ) == 'cfc' ) {
				loadCommand( dir.name, commandPath );
			// For folders, search them for commands
			} else {
				initCommands( dir.directory & '\' & dir.name, listAppend( commandPath, dir.name, '.' ) );
			}
			
		}
		
	}

	/**
	 * load command CFC
	 * @cfc.hint CFC name that represents the command
	 * @commandPath.hint The relative dot-delimted path to the CFC starting in the commands dir
	 **/
	function loadCommand( CFC, commandPath ) {
		
		// Strip cfc extension from filename
		var CFCName = mid( CFC, 1, len( CFC ) - 4 );
		// Build CFC's path
		var fullCFCPath = 'commands.' & iif( len( commandPath ), de( commandPath & '.' ), '' ) & CFCName;
		 		
		// Create this command CFC
		var command = createObject( fullCFCPath );
		
		// Check and see if this CFC instance is a command and has a run() method
		if( !isInstanceOf( command, 'BaseCommand' ) || !structKeyExists( command, 'run' ) ) {
			return;
		}
	
		// Initialize the command
		command.init( instance.shell );
	
		// Mix in some metadata
		decorateCommand( command );
		
		// Add it to the command dictionary
		registerCommand( command, commandPath & '.' & CFCName );
	}
	
	function decorateCommand( required command ) {
		// Grab its metadata
		var CFCMD = getMetadata( command );
		
		// Set up metadata struct
		var commandMD = {
			aliases = listToArray( CFCMD.aliases ?: '' ),
			parameters = [],
			hasHelp = false,
			hint = CFCMD.hint ?: ''
		};
		
		// Check for help() method
		if( structKeyExists( command, 'help' ) ) {
			commandMD.hasHelp = true;
		}
		
		// Capture the command's parameters
		commandMD.parameters = getMetaData(command.run).parameters;
		
		// Inject metadata into command CFC
		command.$CommandBox = commandMD;
		
	}
	
	function registerCommand( required command, required commandPath ) {
		// Build bracketed string of command path to allow special characters
		var commandPathBracket = '';
		for( var item in listToArray( commandPath, '.' ) ) {
			commandPathBracket &= '["#item#"]';
		}
				
		// Register the command in our command dictionary
		evaluate( "instance.commands#commandPathBracket# = command" );
	}

	/**
	 * get help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	function help(String namespace='', String command='')  {
		if(namespace != '' && command == '') {
			if(!isNull(commands[''][namespace])) {
				command = namespace;
				namespace = '';
			} else if(!isNull(commandAliases[''][namespace])) {
				command = commandAliases[''][namespace];
				namespace = '';
			} else if (isNull(commands[namespace])) {
				instance.shell.printError({message:'No help found for #namespace#'});
				return '';
			}
		}
		var result = instance.shell.ansi('green','HELP #namespace# [command]') & cr;
		if(namespace == '' && command == '') {
			for(var commandName in commands['']) {
				var helpText = commands[''][commandName].hint;
				result &= chr(9) & instance.shell.ansi('cyan',commandName) & ' : ' & helpText & cr;
			}
			for(var ns in namespaceHelp) {
				var helpText = namespaceHelp[ns];
				result &= chr(9) & instance.shell.ansi('black,cyan_back',ns) & ' : ' & helpText & cr;
			}
		} else {
			if(!isNull(commands[namespace][command])) {
				result &= getCommandHelp(namespace,command);
			} else if (!isNull(commands[namespace])){
				var helpText = namespaceHelp[namespace];
				result &= chr(9) & instance.shell.ansi('cyan',namespace) & ' : ' & helpText & cr;
				for(var commandName in commands[namespace]) {
					var helpText = commands[namespace][commandName].hint;
					result &= chr(9) & instance.shell.ansi('cyan',commandName) & ' : ' & helpText & cr;
				}
			} else {
				instance.shell.printError({message:'No help found for #namespace# #command#'});
				return '';
			}
		}
		return result;
	}

	/**
	 * get command help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	private function getCommandHelp(String namespace='', String command='')  {
		var result ='';
		var metadata = commands[namespace][command];
		result &= chr(9) & instance.shell.ansi('cyan',command) & ' : ' & metadata.hint & cr;
		result &= chr(9) & instance.shell.ansi('magenta','Arguments') & cr;
		for(var param in metadata.parameters) {
			result &= chr(9);
			if(param.required)
				result &= instance.shell.ansi('red','required ');
			result &= param.type & ' ';
			result &= instance.shell.ansi('magenta',param.name);
			if(!isNull(param.default))
				result &= '=' & param.default & ' ';
			if(!isNull(param.hint))
				result &= ' (#param.hint#)';
		 	result &= cr;
		}
		return result;
	}

	/**
	 * return the shell
 	 **/
	function getShell() {
		return instance.shell;
	}

	/**
	 * run a command line
	 * @line.hint line to run
 	 **/
	function runCommandline(line) {
		// Turn the users input into an array of tokens
		var tokens = tokenizeInput( line );
		// Resolve the command they are wanting to run
		var commandInfo = resolveCommand( tokens );
		
		// If nothing was found, bail out here.
		if( !commandInfo.found ) {
			instance.shell.printError({message:'Command "#line#" cannot be resolved.  Please type "help" for assitance.'});
			return;
		}
		
		var parameterInfo = parseParameters( commandInfo.parameters );
				
		// Parameters need to be ALL positional or ALL named
		if( arrayLen( parameterInfo.positionalParameters ) && structCount( parameterInfo.namedParameters ) ) {
			instance.shell.printError({message:"Please don't mix named and positional parameters, it makes me dizzy."});
			return;
		}
		
		// These are the parameters declared by the command CFC
		var commandParams = commandInfo.commandReference.$CommandBox.parameters;
		
		// If we're using postitional params, convert them to named
		if( arrayLen( parameterInfo.positionalParameters ) ) {
			parameterInfo.namedParameters = convertToNamedParameters( parameterInfo.positionalParameters, commandParams );
		}
		
		// Make sure we have all required params. 
		parameterInfo.namedParameters = ensureRequiredParams( parameterInfo.namedParameters, commandParams );
				
		return commandInfo.commandReference[ 'run' ]( argumentCollection = parameterInfo.namedParameters );
		
	}

	/**
	 * Tokenizes the command line entered by the user.  Returns array with command statements and arguments
	 *
	 * Consider making a dedicated CFC for this since some of the logic could benifit from 
	 * little helper methods to increase readability and reduce duplicate code.
 	 **/
	function tokenizeInput( string line ) {
		
		// Holds token
		var tokens = [];
		// Used to build up each token
		var token = '';
		// Are we currently inside a quoted string
		var inQuotes = false;
		// What quote character is around our current quoted string (' or ")
		var quoteChar = '';
		// Is the current character escaped
		var isEscaped = false;
		// Are we waiting for the "value" portion of a name/value pair. (In case there is whitespace we're wading through)
		var isWaitingOnValue = false;
		// The previous character to handle escape chars.
		var prevChar = '';
		// Pointer to the current character
		var i = 0;
		
		// Loop over each character in the line
		while( ++i <= len( line ) ) {
			// Current character
			char = mid( line, i, 1 );
			// All the remaining characters
			remainingChars = mid( line, i, len( line ) );
			// Reset this every time
			isEscaped = false;
			
			// This character might be escaped
			if( prevChar == '\' ) {
				isEscaped = true;
			}
			
			// If we're in the middle of a quoted string, just keep appending
			if( inQuotes ) {
				token &= char;
				// We just reached the end of our quoted string
				if( char == quoteChar && !isEscaped ) {
					inQuotes = false;
					tokens.append( token);
					token = '';
				}
				prevChar = char;
				continue;
			}
			
			// Whitespace demarcates tokens outside of quotes
			// Whitespace outside of a quoted string is dumped and not added to the token
			if( trim(char) == '' ) {
				
				// Don't break if an = is next ...
				if( left( trim( remainingChars ), 1 ) == '=' ) {
					isWaitingOnValue = true;
					prevChar = char;
					continue;
				// ... or if we just processed one and we're waiting on the value.
				} else if( isWaitingOnValue ) {
					prevChar = char;
					continue;
				// Append what we have and start anew
				} else {
					if( len( token ) ) {
						tokens.append( token);
						token = '';					
					}
					prevChar = char;
					continue;
				}
			}
			
			// We're starting a quoted string
			if( ( char == '"' || char == "'" ) && !isEscaped ) {
				inQuotes = true;
				quoteChar = char;
			}
			
			// Keep appending
			token &= char;
			
			// If we're waiting for a value in a name/value pair and just hit something OTHER than an =
			if( isWaitingOnValue && char != '=' ) {
				// Then the wait is over
				isWaitingOnValue = false;
			}
			
			prevChar = char;
			
		} // end while
		
		// Anything left after the loop is our last token
		if( len( token ) ) {
			tokens.append( token);					
		}
		
		return tokens;
	}



	/**
	 * Figure out what command to run based on the tokenized user input
 	 **/
	function resolveCommand( tokens ) {
		
		var cmds = instance.commands;
		
		var results = {
			commandString = '',
			commandReference = cmds,
			parameters = [],
			found = false
		};
		
		var lastHelpReference = '';
					
		// Check for a root help command
		if( structKeyExists( results.commandReference, 'help' ) && isObject( results.commandReference.help ) ) {
			lastHelpReference = results.commandReference.help;
		}
		
		for( var token in tokens ) {
			
			// If we hit a dead end, then quit looking
			if( !structKeyExists( results.commandReference, token ) ) {
				break;
			}
			
			// Move the pointer
			results.commandString = listAppend( results.commandString, token, '.' );
			results.commandReference = results.commandReference[ token ];
			
			// If we've reached a CFC, we're done
			if( isObject( results.commandReference ) ) {
				results.found = true;
				break;
			// If this is a folder, check and see if it has a "help" command
			} else {	
				if( structKeyExists( results.commandReference, 'help' ) && isObject( results.commandReference.help ) ) {
					lastHelpReference = results.commandReference.help;
				}
			}
			
			
		} // end for loop
		
		// If we found a command, carve the parameters off the end
		var commandLength = listLen( results.commandString, '.' );
		var tokensLength = arrayLen( tokens );
		if( results.found && commandLength < tokensLength ) {
			results.parameters = tokens.slice( commandLength+1 );			
		}
		
		// If we failed to match a command, but we did encounter a help command along the way, make that the new command
		if( !results.found && isObject( lastHelpReference ) ) {
			results.commandReference = lastHelpReference;
			results.found = true;
		}
		
		return results;
				
	}


	/**
	 * Parse an array of parameter tokens. unescape values and determine if named or positional params are being used.
 	 **/
	function parseParameters( required array parameters ) {
		
		var results = {
			positionalParameters = [],
			namedParameters = {}
		};
		
		if( !arrayLen( parameters ) ) {
			return results;			
		}
		
		for( var param in parameters ) {
			
			// Remove escaped characters
			param = removeEscapedChars( param );
			
			// named params
			if( listLen( param, '=' ) > 1 ) {
				// Extract the name and value pair
				var name = listFirst( param, '=' );
				var value = listRest( param, '=' );
				
				// Unwrap quotes from value if used
				value = unwrapQuotes( value );
				
				name = replaceEscapedChars( name );
				value = replaceEscapedChars( value );
								
				results.namedParameters[ name ] = value;
				
			// Positional params
			} else {
				// Unwrap quotes from value if used
				param = unwrapQuotes( param );
				results.positionalParameters.append( param );				
			}
						
		}
		
		return results;
		
	}
	
	
	private function unwrapQuotes( theString ) {
		if( left( theString, 1 ) == '"' or left( theString, 1 ) == "'") {
			return mid( theString, 2, len( theString ) - 2 );
		}
		return theString;
	}
	
	private function removeEscapedChars( theString ) {
		theString = replaceNoCase( theString, "\'", '__singleQuote__', "all" );
		theString = replaceNoCase( theString, '\"', '__doubleQuote__', "all" );
		return		replaceNoCase( theString, '\=', '__equalSign__', "all" );
	}
	
	private function replaceEscapedChars( theString ) {
		theString = replaceNoCase( theString, '__singleQuote__', "\'", "all" );
		theString = replaceNoCase( theString, '__doubleQuote__', '\"', "all" );
		return		replaceNoCase( theString, '__equalSign__', '\=', "all" );
	}

	/**
	 * Match positional parameters up with their names 
 	 **/
	private function convertToNamedParameters( userPositionalParams, commandParams ) {
		var results = {};
		
		var i = 0;
		// For each param the user typed in
		for( var param in userPositionalParams ) {
			i++;
			// Figure out its name
			if( arrayLen( commandParams ) >= i ){
				results[ commandParams[i].name ] = param;
			// Extra user params just get assigned a name
			} else {
				results[ i ] = param;
			}
		}
		
		return results;		
	}



	/**
	 * Make sure we have all required params
 	 **/
	private function ensureRequiredparams( userNamedParams, commandParams ) {
		
		// For each command param
		for( var param in commandParams ) {
			// If it's required and hasn't been supplied...
			if( param.required && !structKeyExists( userNamedParams, param.name ) ) {
				// ... Ask the user
				var message = 'Enter #param.name#';
				if( structKeyExists( param, 'hint' ) ) {
					message &= ' (#param.hint#)';	
				}
				message &= ' : ';
           		var value = instance.shell.ask( message );
           		userNamedParams[ param.name ] = value;				
			}
		} // end for loop
		
		return userNamedParams;
	}


	/**
	 * return a list of base commands (includes namespaces)
 	 **/
	function listCommands() {
		return structKeyList( instance.commands );
	}

	/**
	 * return the namespaced command structure
 	 **/
	function getCommands() {
		return instance.commands;
	}

}