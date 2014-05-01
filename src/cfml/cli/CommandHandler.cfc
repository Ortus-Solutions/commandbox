/**
 * Command handler
 * @author Denny Valliant
 **/
component output='false' persistent='false' {

	instance = {
		// Refernce to the shell instance
		shell = '',
		
		// A nested struct of the registered commands
		commands = {},
		
		// The same command data, but more useful for help and such
		flattenedCommands = {},
		
		// The directory the CommandHandler lives in
		thisdir = getDirectoryFromPath(getMetadata(this).path),
		
		// Java system reference
		System = createObject('java', 'java.lang.System'),
		
		// A stack of running commands in case one command calls another from within
		callStack = []
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
        instance.parser = new parser();
		initCommands();				
		var completor = createDynamicProxy(new Completor(this), ['jline.Completor']);
        reader.addCompletor(completor);
		return this;
	}

	/**
	 * initialize the commands. This will recursively call itself for subdirectories.
	 **/
	function initCommands( commandDirectory = instance.rootCommandDirectory, commandPath='' ) {
		var varDirs = DirectoryList( path=commandDirectory, recurse=false, listInfo='query', sort='type desc, name asc' );
		for(var dir in varDirs){
			
			// For CFC files, process them as a command
			if( dir.type  == 'File' && listLast( dir.name, '.' ) == 'cfc' ) {
				loadCommand( dir.name, commandPath );
			// For folders, search them for commands
			// Temporary exclusion for 'home' dir in cfdistro
			} else if( dir.name != 'home' ) {
				initCommands( dir.directory & '\' & dir.name, listAppend( commandPath, dir.name, '.' ) );
			}
			
		}
		
	}

	/**
	 * load command CFC
	 * @cfc.hint CFC name that represents the command
	 * @commandPath.hint The relative dot-delimted path to the CFC starting in the commands dir
	 **/
	private function loadCommand( CFC, commandPath ) {
		
		// Strip cfc extension from filename
		var CFCName = mid( CFC, 1, len( CFC ) - 4 );
		var commandName = iif( len( commandPath ), de( commandPath & '.' ), '' ) & CFCName;
		// Build CFC's path
		var fullCFCPath = 'commands.' & commandName;
		 		
		// Create this command CFC
		var command = createObject( fullCFCPath );
		
		// Check and see if this CFC instance is a command and has a run() method
		if( !isInstanceOf( command, 'BaseCommand' ) || !structKeyExists( command, 'run' ) ) {
			return;
		}
	
		// Initialize the command
		command.init( instance.shell );
	
		// Mix in some metadata
		decorateCommand( command, commandName );
		
		// Add it to the command dictionary
		registerCommand( command, commandPath & '.' & CFCName );
		
		// Register the aliases
		for( var alias in command.$CommandBox.aliases ) {
			registerCommand( command, commandPath & '.' & trim(alias) );
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
		var commandInfo = resolveCommand( line );
		
		// If nothing was found, bail out here.
		if( !commandInfo.found ) {
			instance.shell.printError({message:'Command "#line#" cannot be resolved.  Please type "help" for assitance.'});
			return;
		}
		
		// For help commands squish all the parameters together into one be one exactly as typed
		if( listLast( commandInfo.commandReference.$CommandBox.originalName, '.' ) == 'help' ) {
			var parameterInfo = {
				positionalParameters = [ arrayToList( commandInfo.parameters, ' ' ) ],
				namedParameters = {}
			};
		// For normal commands, parse them out propery
		} else {
			var parameterInfo = instance.parser.parseParameters( commandInfo.parameters );
		}
				
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
		
		// Reset the printBuffer
		commandInfo.commandReference.reset();
		
		// If there are currently executing commands, flush out the print buffer from the last one
		// This will preven the output from showing up out of order if one command nests a call to another.
		if( instance.callStack.len() ) {
			// Print anything in the buffer
			instance.shell.printString( instance.callStack[1].commandReference.getResult() );
			// And reset it now that it's been printed.  
			// This command can add more to the buffer once it's executing again.
			instance.callStack[1].commandReference.reset();
		}
		
		// Add command to the top of the stack
		instance.callStack.prepend( commandInfo );
		
		// Run the command
		var result = commandInfo.commandReference.run( argumentCollection = parameterInfo.namedParameters );
		
		// Remove it from the stack
		instance.callStack.deleteAt( 1 );
		
		// If the command didn't return anything, grab its print buffer value 
		if( isNull( result ) ) {
			result = commandInfo.commandReference.getResult();
		}
		
		return result;
		
	}


	/**
	 * Figure out what command to run based on the tokenized user input
	 * @line.hint A string containing the command and parameters that the user entered
	 * @substituteHelp.hint If the command cannot be found, switch it out for the closest help 
 	 **/
	function resolveCommand( required string line, substituteHelp = true ) {
		
		// Turn the users input into an array of tokens
		var tokens = instance.parser.tokenizeInput( line );
		
		var cmds = instance.commands;
		
		var results = {
			commandString = '',
			commandReference = cmds,
			parameters = [],
			found = false
		};
		
		var lastHelpReference = '';
					
		// Check for a root help command
		if( substituteHelp &&  structKeyExists( results.commandReference, 'help' ) && isObject( results.commandReference.help ) ) {
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
				if( substituteHelp && structKeyExists( results.commandReference, 'help' ) && isObject( results.commandReference.help ) ) {
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
			// Dump app the tokens in a parameters
			results.parameters = tokens;
			results.found = true;
		}
		
		return results;
				
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
	 * return the shell
 	 **/
	function getShell() {
		return instance.shell;
	}
}