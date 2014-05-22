/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle initializing, reading, and running commands
*
*/
component singleton {

	property name='shell' inject='Shell';
	property name='parser' inject='Parser'; 

	// TODO: Convert these to properties
	instance = {
		// Reference to the shell instance
		shell = '',
		
		// A nested struct of the registered commands
		commands = {},
		
		// The same command data, but more useful for help and such
		flattenedCommands = {},
				
		// Java system reference
		System = createObject('java', 'java.lang.System'),
		
		// A stack of running commands in case one command calls another from within
		callStack = []
	};
		
	// This is where system commands are stored
	instance.systemCommandDirectory = '/commandbox/system/commands';
	// This is where user commands are stored
	instance.userCommandDirectory = '/commandbox/commands';
	
	// Convenience value
	cr = instance.System.getProperty('line.separator');

	/**
	 * Constructor
	 **/
	function init() {
		return this;
	} 
	
	function configure() {
        
	//	systemOutput( 'System commands...', true );
        // Load system commands
		initCommands( instance.systemCommandDirectory, instance.systemCommandDirectory );
	//	systemOutput( 'User commands...', true );
        // Load user commands
		initCommands( instance.userCommandDirectory, instance.userCommandDirectory );
	//	systemOutput( 'Done...', true );
		
	} 

	/**
	 * initialize the commands. This will recursively call itself for subdirectories.
	 **/
	function initCommands( baseCommandDirectory, commandDirectory, commandPath='' ) {
		var varDirs = DirectoryList( path=commandDirectory, recurse=false, listInfo='query', sort='type desc, name asc' );
		for(var dir in varDirs){
			
			// For CFC files, process them as a command
			if( dir.type  == 'File' && listLast( dir.name, '.' ) == 'cfc' ) {
				loadCommand( baseCommandDirectory, dir.name, commandPath );
			// For folders, search them for commands
			// Temporary exclusion for 'home' dir in cfdistro
			} else if( dir.name != 'home' ) {
				initCommands( baseCommandDirectory, dir.directory & '\' & dir.name, listAppend( commandPath, dir.name, '.' ) );
			}
			
		}
		
	}

	/**
	 * load command CFC
	 * @baseCommandDirectory.hint The base directory for this command
	 * @cfc.hint CFC name that represents the command
	 * @commandPath.hint The relative dot-delimted path to the CFC starting in the commands dir
	 **/
	private function loadCommand( baseCommandDirectory, CFC, commandPath ) {
		
		// Strip cfc extension from filename
		var CFCName = mid( CFC, 1, len( CFC ) - 4 );
		var commandName = iif( len( commandPath ), de( commandPath & '.' ), '' ) & CFCName;
		// Build CFC's path
		var fullCFCPath = baseCommandDirectory & '.' & commandName;
		 		
		// Create this command CFC
		try {
			var command = application.wireBox.getInstance( fullCFCPath );
		// This will catch nasty parse errors so the shell can keep loading
		} catch( any e ) {
			systemOutput( 'Error loading command [#fullCFCPath#]#CR##CR#' );
			// pretty print the exception
			shell.printError( e );
			return;
		}
		
		// Check and see if this CFC instance is a command and has a run() method
		if( !isInstanceOf( command, 'BaseCommand' ) || !structKeyExists( command, 'run' ) ) {
			return;
		}
	
		// Initialize the command
		command.init( shell );
	
		// Mix in some metadata
		decorateCommand( command, commandName );
		
		// Add it to the command dictionary
		registerCommand( command, commandPath & '.' & CFCName );
		
		// Register the aliases
		for( var alias in command.$CommandBox.aliases ) {
			// Alias is allowed to be anything.  This means it may even overwrite another command already loaded.
			registerCommand( command, listChangeDelims( trim( alias ), '.', ' ' ) );
		}
	}
	
	function decorateCommand( required command, required commandName ) {
		// Grab its metadata
		var CFCMD = getMetadata( command );
		
		// Set up metadata struct
		var commandMD = {
			aliases = listToArray( CFCMD.aliases ?: '' ),
			parameters = [],
			hint = CFCMD.hint ?: '',
			originalName = commandName,
			excludeFromHelp = CFCMD.excludeFromHelp ?: false
		};
						
		// Capture the command's parameters
		commandMD.parameters = getMetaData(command.run).parameters;
		
		// Inject metadata into command CFC
		command.$CommandBox = commandMD;
		
	}
	
	function registerCommand( required command, required commandPath ) {
		// Build bracketed string of command path to allow special characters
		var commandPathBracket = '';
		var commandName = '';
		for( var item in listToArray( commandPath, '.' ) ) {
			commandPathBracket &= '[ "#item#" ]';
			commandName &= "#item# ";
		}
				
		// Register the command in our command dictionary
		evaluate( "instance.commands#commandPathBracket# = command" );
		
		// And again here in this flat collection for help usage
		instance.flattenedCommands[ trim(commandName) ] = command;
	}

	/**
	 * run a command line
	 * @line.hint line to run
 	 **/
	function runCommandline(line) {
		
		// Resolve the command they are wanting to run
		var commandChain = resolveCommand( line );
		
		var i = 0;
		// If piping commands, each one will be an item in the chain.
		// i.e. forgebox show | grep | more 
		// Would result in three separate, chained commands.
		for( var commandInfo in commandChain ) {
			i++;
			
			// If nothing was found, bail out here.
			if( !commandInfo.found ) {
				shell.printError({message:'Command "#line#" cannot be resolved.  Please type "#trim( "help #listChangeDelims( commandInfo.commandString, ' ', '.' )#" )#" for assistance.'});
				return;
			}
			
			// For help commands squish all the parameters together into one exactly as typed
			if( listLast( commandInfo.commandReference.$CommandBox.originalName, '.' ) == 'help' ) {
				var parameterInfo = {
					positionalParameters = [ arrayToList( commandInfo.parameters, ' ' ) ],
					namedParameters = {}
				};
			// For normal commands, parse them out properly
			} else {
				var parameterInfo = parseParameters( commandInfo.parameters );
			}
			
			// Parameters need to be ALL positional or ALL named
			if( arrayLen( parameterInfo.positionalParameters ) && structCount( parameterInfo.namedParameters ) ) {
				shell.printError({message:"Please don't mix named and positional parameters, it makes me dizzy."});
				return;
			}
			
			// These are the parameters declared by the command CFC
			var commandParams = commandInfo.commandReference.$CommandBox.parameters;
						
			// If this is not the first command in the chain, 
			// set its first parameter with the output from the last command
			if( i > 1 ) {
				// If we're using named parameters and this command has at least one param defined
				if( structCount( parameterInfo.namedParameters ) ) {
					// Insert/overwrite the first param as our last result
					parameterInfo.namedParameters[ commandParams[1].name ?: '1' ] = result;
				} else {
					parameterInfo.positionalParameters.prepend( result );					
				}
			}
			
			// If we're using postitional params, convert them to named
			if( arrayLen( parameterInfo.positionalParameters ) ) {
				parameterInfo.namedParameters = convertToNamedParameters( parameterInfo.positionalParameters, commandParams );
			}
			
			// Make sure we have all required params. 
			parameterInfo.namedParameters = ensureRequiredParams( parameterInfo.namedParameters, commandParams );
						
			// Reset the printBuffer
			commandInfo.commandReference.reset();
			
			// If there are currently executing commands, flush out the print buffer from the last one
			// This will prevent the output from showing up out of order if one command nests a call to another.
			if( instance.callStack.len() ) {
				// Print anything in the buffer
				shell.printString( instance.callStack[1].commandReference.getResult() );
				// And reset it now that it's been printed.  
				// This command can add more to the buffer once it's executing again.
				instance.callStack[1].commandReference.reset();
			}
			
			// Add command to the top of the stack
			instance.callStack.prepend( commandInfo );
			
			// Run the command
			try {
				var result = commandInfo.commandReference.run( argumentCollection = parameterInfo.namedParameters );
			} catch( any e ) {
				// Dump out anything the command had printed so far
				var result = commandInfo.commandReference.getResult();
				if( len( result ) ) {
					shell.printString( result & cr );
				}
				// Clean up a bit
				instance.callStack.clear();
				// Now, where were we?
				rethrow;
			}
			
			// Remove it from the stack
			instance.callStack.deleteAt( 1 );
			
			// If the command didn't return anything, grab its print buffer value 
			if( isNull( result ) ) {
				result = commandInfo.commandReference.getResult();
			}
						
		
		} // End loop over command chain
		
		return result;
		
	}

	/**
	 * Take an array of parameters and parse them out as named or positional
	 * @parameters.hint The array of params to parse. 
 	 **/
	function parseParameters( parameters ) {
		return parser.parseParameters( parameters );
	}

	/**
	 * Figure out what command to run based on the tokenized user input
	 * @line.hint A string containing the command and parameters that the user entered
 	 **/
	function resolveCommand( required string line ) {
		
		// Turn the users input into an array of tokens
		var tokens = parser.tokenizeInput( line );
		// This will hold the command chain. Usually just a single command,
		// but a pipe ("|") will chain together commands and pass the output of one along as the input to the next		
		var commandsToResolve = [[]];
		var commandChain = [];
		
		// If this command has a pipe, we need to chain multiple commands
		if( tokens.find( '|' ) ) {
			var i = 0;
			for( var token in tokens ) {
				i++;
				if( token != '|' ) {
					//Append this token to the last command
					commandsToResolve[ commandsToResolve.len() ].append( token );					
				} else if( commandsToResolve[ commandsToResolve.len() ].len() && i < tokens.len() ) {
					// Add a new command
					commandsToResolve.append( [] );
				}
			}
		// If there's no pipe, then there is only 1 command to resolve
		} else {
			commandsToResolve[ 1 ] = tokens;
		}
		
		
		// command hierarchy
		var cmds = getCommandHierarchy();
		
		for( var commandTokens in commandsToResolve ) {
				
			tokens = commandTokens;
			
			// If command ends with "help", switch it around to call the root help command
			// Ex. "coldbox help" becomes "help coldbox"
			// Don't do this if we're already in a help command or endless recursion will ensue.
			if( tokens.len() > 1 && tokens.last() == 'help' && !inCommand( 'help' ) ) {
				// Move help to the beginning
				tokens.deleteAt( tokens.len() );
				tokens.prepend( 'help' );
			}
			
			var results = {
				commandString = '',
				commandReference = cmds,
				parameters = [],
				found = false,
				closestHelpCommand = 'help'
			};
						
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
						results.closestHelpCommand = listChangeDelims( results.commandString, ' ', '.' ) & ' help';
					}
				}
				
				
			} // end for loop
			
			// If we found a command, carve the parameters off the end
			var commandLength = listLen( results.commandString, '.' );
			var tokensLength = arrayLen( tokens );
			if( results.found && commandLength < tokensLength ) {
				results.parameters = tokens.slice( commandLength+1 );
			}
			
			commandChain.append( results );

		} // end loop over commands to resolve
		
		// Return command chain			
		return commandChain;
				
	}

		
	/**
	 * Looks at the call stack to determine if we're currently "inside" a command.
	 * Useful to prevent endless recursion. 
	 * @command.hint Name of the command to look for as typed from the shell.  If empty, returns true for any command
 	 **/
	function inCommand( command='' ) {
			
		// If a command is provided, look for it in the call stack..
		if( len( command ) ) {
			for( var call in instance.callStack ) {
				// CommandString is a dot-delimted path
				if( call.commandString == listChangeDelims( command, ' ', '.' ) ) {
					return true;
				}					
			}
			// Nope, not found
			return false;			
		} else {
			// If no specific command given, just look for any thing in the stack
			return instance.callStack.len() ? true : false;
		}
			
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
           		var value = shell.ask( message );
           		// TODO: Add validation here to make sure the 
           		// value entered matches the type!
           		userNamedParams[ param.name ] = value;				
			}
		} // end for loop
		
		return userNamedParams;
	}


	/**
	 * return a list of base commands
 	 **/
	function listCommands() {
		return structKeyList( instance.flattenedCommands );
	}

	/**
	 * return the command structure
 	 **/
	function getCommands() {
		return instance.flattenedCommands;
	}

	/**
	 * return the nested command structure
 	 **/
	function getCommandHierarchy() {
		return instance.Commands;
	}


	/**
	 * return the shell
 	 **/
	function getShell() {
		return shell;
	}
}