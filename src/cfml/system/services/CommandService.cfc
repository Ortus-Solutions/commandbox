/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle initializing, reading, and running commands
*/
component accessors="true" singleton {

	// DI Properties
	property name='shell' 				inject='Shell';
	property name='wirebox'				inject='wirebox';
	property name="fileSystemUtil"		inject='FileSystem';
	property name='parser' 				inject='Parser';
	property name='system' 				inject='System@constants';
	property name='cr' 					inject='cr@constants';
	property name='logger' 				inject='logbox:logger:{this}';
	property name='consoleLogger'		inject='logbox:logger:console';
	property name='wirebox' 			inject='wirebox';
	property name='commandLocations'	inject='commandLocations@constants';
	property name='interceptorService'	inject='interceptorService';
	// Using provider since CommandService is created before modules are loaded
	property name='stringDistance'		inject='provider:StringSimilarity@string-similarity';
	property name='SystemSettings'		inject='SystemSettings';
	property name='ConfigService'		inject='ConfigService';
	property name='metadataCache'		inject='cachebox:metadataCache';
	property name='FRTransService'		inject='FRTransService';
	property name='job'					inject='provider:InteractiveJob';

	property name='configured' default="false" type="boolean";

	// TODO: Convert these to properties
	instance = {
		// A nested struct of the registered commands
		commands = {},
		// The same command data, but more useful for help and such
		flattenedCommands = {},
		// A stack of running commands in case one command calls another from within
		callStack = []
	};

	/**
	 * Constructor
	 **/
	function init(){
		setConfigured( false );
		return this;
	}

	/**
	* Configure the service
	*/
	CommandService function configure(){
		// Check if handler mapped?
		if( NOT wirebox.getBinder().mappingExists( 'commandbox.system.BaseCommand' ) ){
			// feed the base class
			wirebox.registerNewInstance( name='commandbox.system.BaseCommand', instancePath='commandbox.system.BaseCommand' )
				.setAutowire( false );
		}

		// map commands
		for( var commandLocation in commandLocations ){

			// Ensure location exists
			if( !directoryExists( expandPath( commandLocation ) ) ){
				directoryCreate( expandPath( commandLocation ) );
			}
			// Load up any commands
			initCommands( commandLocation );
		}

		setConfigured( true );
		return this;
	}

	/**
	 * Initialize the commands. This will recursively call itself for subdirectories.
	 * @baseCommandDirectory The starting directory
	 * @commandDirectory The current directory we've recursed into
	 * @commandPath The dot-delimited path so far-- only used when recursing
	 **/
	CommandService function initCommands(
		required string baseCommandDirectory,
		string commandDirectory=baseCommandDirectory,
		string commandPath=''
	){
		var varDirs = DirectoryList(
			path		= expandPath( arguments.commandDirectory ),
			recurse		= false,
			listInfo	= 'query',
			sort		= 'type desc, name asc'
		);

		for( var dir in varDirs ){
			// For CFC files, process them as a command
			if( dir.type  == 'File' && listLast( dir.name, '.' ) == 'cfc' ){
				registerCommand( baseCommandDirectory, dir.name, commandPath );
			// For folders, search them for commands
			} else {
				initCommands( baseCommandDirectory, dir.directory & '\' & dir.name, listAppend( commandPath, dir.name, '.' ) );
			}
		}

		return this;
	}

	/**
	 * Remove commands from the CommandService. This will recursively call itself for subdirectories.
	 * @baseCommandDirectory The starting directory
	 * @commandDirectory The current directory we've recursed into
	 * @commandPath The dot-delimited path so far-- only used when recursing
	 **/
	CommandService function removeCommands(
		required string baseCommandDirectory,
		string commandDirectory=baseCommandDirectory,
		string commandPath=''
	){
		var varDirs = DirectoryList(
			path		= expandPath( arguments.commandDirectory ),
			recurse		= false,
			listInfo	= 'query',
			sort		= 'type desc, name asc'
		);

		for( var dir in varDirs ){
			// For CFC files, process them as a command
			if( dir.type  == 'File' && listLast( dir.name, '.' ) == 'cfc' ){
				removeCommand( baseCommandDirectory, dir.name, commandPath );
			// For folders, search them for commands
			} else {
				removeCommands( baseCommandDirectory, dir.directory & '\' & dir.name, listAppend( commandPath, dir.name, '.' ) );
			}
		}

		return this;
	}

	function addToDictionary( required command, required commandPath ){

		// Build bracketed string of command path to allow special characters
		var commandPathBracket = '';
		var commandName = '';
		for( var item in listToArray( commandPath, '.' ) ){
			commandPathBracket &= '[ "#item#" ]';
			commandName &= "#item# ";
		}

		// Register the command in our command dictionary
		evaluate( "instance.commands#commandPathBracket#[ '$' ] = command" );

		// And again here in this flat collection for help usage
		instance.flattenedCommands[ trim(commandName) ] = command;
	}

	function removeFromDictionary( required command, required commandPath ){

		// Build bracketed string of command path to allow special characters
		var commandPathBracket = '';
		var commandName = '';

		commandPathArray = listToArray( commandPath, '.' );

		for( var item in commandPathArray ){
			commandPathBracket &= '[ "#item#" ]';
			commandName &= "#item# ";
		}

		// This happens if a command is registered twice and we've already removed it
		if( !isDefined( "instance.commands#commandPathBracket#" ) ) {
			return;
		}

		// Here in this flat collection for help usage
		instance.flattenedCommands.delete( trim(commandName) );

		if( isDefined( "instance.commands#commandPathBracket#[ '$' ]" ) ) {
			evaluate( "structDelete( instance.commands#commandPathBracket#, '$' )" );
		}


		// Remove from the leaf nodes up, removing any empty namespaces as we go.
		// We can't just kill the namespace, because a command that contributes a "server foobar" command would not want to remove the 'server' namespace.
		while( commandPathArray.len() ) {

			// If there are other commands in this namespace, we're done
			if( evaluate( "structCount( instance.commands#commandPathBracket# )" ) ) {
				break;
			}

			// If this namespace is empty, pop last item off the array and remove it
			var lastItem = commandPathArray.pop();

			commandPathBracket = '';
			for( var item in commandPathArray ){
				commandPathBracket &= '[ "#item#" ]';
			}

			evaluate( "structDelete( instance.commands#commandPathBracket#, lastItem )" );

			// We'll keep climbing "up" in our while() until we run out of namespaces, or we reach a namespace that still populated

		}


	}


	/**
	 * run a command line
	 * @line line to run
	 * @captureOutput Temp workaround to allow capture of run command
 	 **/
	function runCommandline( required string line, boolean captureOutput=false ){

		if( left( arguments.line, 4 ) == 'box ' && len( arguments.line ) > 4 ) {
			consoleLogger.warn( "Removing extra text [box ] from start of command. You don't need that here." );
			arguments.line = right( arguments.line, len( arguments.line ) - 4 );
		}

		// Resolve the command they are wanting to run
		var commandChain = resolveCommand( line );

		return runCommand( commandChain=commandChain, line=line, captureOutput=captureOutput );
	}

	/**
	 * run a command tokens
	 * @tokens tokens to run
	 * @piped Data to pipe in to the first command
	 * @captureOutput Temp workaround to allow capture of run command
 	 * @line This is the original, unparsed line typed by the user
 	 **/
	function runCommandTokens( required array tokens, string piped, boolean captureOutput=false, required string line ){

		// Resolve the command they are wanting to run
		var commandChain = resolveCommandTokens( tokens, line );

		// If there was piped input
		if( structKeyExists( arguments, 'piped' ) ) {
			return runCommand( commandChain, line, arguments.piped, captureOutput );
		}

		return runCommand( commandChain=commandChain, line=line, captureOutput=captureOutput );

	}

	/**
	 * run a command
	 * @commandChain the chain of commands to run
	 * @captureOutput Temp workaround to allow capture of run command
 	 **/
	function runCommand( required array commandChain, required string line, string piped, boolean captureOutput=false ){
		// If nothing is returned, something bad happened (like an error instantiating the CFC)
		if( !commandChain.len() ){
			return 'Command not run.';
		}

		var i = 0;
		// default behavior is to keep trucking
		var previousCommandSeparator = ';';
		var lastCommandErrored = false;
		var captureOutputOriginal = captureOutput;

		if( structKeyExists( arguments, 'piped' ) ) {
			var result = arguments.piped;
			previousCommandSeparator = '|';
		}

		// If piping commands, each one will be an item in the chain.
		// i.e. forgebox show | grep | more
		// Would result in three separate, chained commands.
		for( var commandInfo in commandChain ){
			i++;

			// If we've reached a command separator like "foo | bar" or "baz && bum", make note of it and continue
			if( listFindNoCase( ';,|,||,&&', commandInfo.originalLine ) ) {
				previousCommandSeparator = commandInfo.originalLine;
				continue;
			}

			if( previousCommandSeparator == '&&' && lastCommandErrored ) {
				continue;
				return result ?: '';
			}

			if( previousCommandSeparator == '||' && !lastCommandErrored ) {
				continue;
				return result ?: '';
			}

			// If nothing was found, bail out here.
			if( !commandInfo.found ){
				var detail = generateListOfSimilarCommands( commandInfo );
				shell.setExitCode( 1 );
				throw( message='Command "#line#" cannot be resolved.', detail=detail, type="commandException");
			}

			// For help commands squish all the parameters together into one exactly as typed
			if( listLast( commandInfo.commandReference.originalName, '.' ) == 'help' ){
				var parameterInfo = {
					positionalParameters = [ arrayToList( commandInfo.parameters, ' ' ) ],
					namedParameters = {},
					flags = {}
				};
			// For run don't process the parameter, just pass it right along.
			} else if( commandInfo.commandReference.originalName == 'run' && commandInfo.parameters.len() ){
				var parameterInfo = {
					positionalParameters = [ commandInfo.parameters[ 1 ] ],
					namedParameters = {},
					flags = {}
				};
			// For normal commands, parse them out properly
			} else {
				var parameterInfo = parseParameters( commandInfo.parameters, commandInfo.commandReference.parameters );
			}

			// Parameters need to be ALL positional or ALL named
			if( arrayLen( parameterInfo.positionalParameters ) && structCount( parameterInfo.namedParameters ) ){
				shell.setExitCode( 1 );
				var detail = "You specified named parameters: #structKeyList(parameterInfo.namedParameters)# but you did not specify a name for: #parameterInfo.positionalParameters[1]# #chr(10)##chr(9)#" & line;
				throw( message='Please don''t mix named and positional parameters, it makes me dizzy.', detail=detail, type="commandException");
			}

			// These are the parameters declared by the command CFC
			var commandParams = commandInfo.commandReference.parameters;

			// If this is not the first command in the chain,
			// set its first parameter with the output from the last command
			if( previousCommandSeparator == '|' && structKeyExists( local, 'result' ) ){
				// Clean off trailing any CR to help with piping one-liner outputs as inputs to another command
				if( result.endsWith( chr( 10 ) ) && len( result ) > 1 ){
					local.result = left( result, len( result ) - 1 );
				}
				// If we're using named parameters and this command has at least one param defined
				if( structCount( parameterInfo.namedParameters ) ){
					if( commandInfo.commandString == 'cfml' ) {
						shell.setExitCode( 1 );
						throw( message='Sorry, you can''t pipe data into a CFML function using named parameters since I don''t know the name of the piped parameter.', detail=line, type="commandException");
					}
					// Insert/overwrite the first param as our last result
					parameterInfo.namedParameters[ commandParams[1].name ?: '1' ] = result;
				} else {
					if( commandInfo.commandString == 'cfml' ) {
						parameterInfo.positionalParameters.insertAt( 2, result );
					} else {
						parameterInfo.positionalParameters.prepend( result );
					}
				}
			// If we're not piping, output what we've got
			} else {
				if( structKeyExists( local, 'result' ) && len( result ) ){
					if( job.getActive() ) {
						job.addLog( result );
					} else {
						shell.printString( result & cr );
					}
				}
				structDelete( local, 'result', false );
			}

			// Reset the printBuffer
			commandInfo.commandReference.CFC.reset();

			// Tells us if we are going to capture the output of this command and pass it to another
			// Used for our workaround to switch if the "run" command pipes to the terminal or not
			// If there are more commands in the chain and we are going to pipe or redirect to them
			if( arrayLen( commandChain ) > i && listFindNoCase( '|,>,>>', commandChain[ i+1 ].originalLine ) ) {
				captureOutput = true;
			}

			// If there are currently executing commands, flush out the print buffer from the last one
			// This will prevent the output from showing up out of order if one command nests a call to another.
			if( instance.callStack.len() && !captureOutput ){
				// Print anything in the buffer
				var job = wirebox.getInstance( 'interactiveJob' );
				// If there is an active job, print our output through it
				if( job.getActive() ) {
					job.addLog( instance.callStack[1].commandInfo.commandReference.CFC.getResult() );
				} else {
					shell.printString( instance.callStack[1].commandInfo.commandReference.CFC.getResult() );
				}
				// And reset it now that it's been printed.
				// This command can add more to the buffer once it's executing again.
				instance.callStack[1].commandInfo.commandReference.CFC.reset();
			}

			// Add command to the top of the stack
			instance.callStack.prepend( { commandInfo : commandInfo, environment : {} } );

			if( captureOutput ) {
				// This is really just a workaround for the fact that command output isn't naturally piped to the console.
				// Once that is fixed, commands will no longer need to know this.
				systemsettings.setSystemSetting( 'box_currentCommandPiped', true );
			// Override this if necessary, but don't set it just for the fun of it
			} else if( systemsettings.getSystemSetting( 'box_currentCommandPiped', false ) ) {
				systemsettings.setSystemSetting( 'box_currentCommandPiped', false );
			}

			// Start the try as soon as we prepend to the call stack so any errors from here on out, even parsing the params, will
			// correctly remove this call from the stack in the finally block.
			try {
				var FRTrans = FRTransService.startTransaction( commandInfo.commandString.listChangeDelims( ' ', '.' ), commandInfo.originalLine );

				// If we're using positional params, convert them to named
				if( arrayLen( parameterInfo.positionalParameters ) ){
					parameterInfo.namedParameters = convertToNamedParameters( parameterInfo.positionalParameters, commandParams );
				}

				// Merge flags into named params
				mergeFlagParameters( parameterInfo );

				// Add in defaults for every possible alias of this command
				[]
					.append( commandInfo.commandReference.originalName.replace( '.', ' ', 'all' ) )
					.append( commandInfo.commandReference.aliases, true )
					.each( function( thisName ) {
						addDefaultParameters( thisName, parameterInfo );
					} );

				// Make sure we have all required params.
				parameterInfo.namedParameters = ensureRequiredParams( parameterInfo.namedParameters, commandParams );

				interceptorService.announceInterception( 'preCommandParamProcess', { commandInfo=commandInfo, parameterInfo=parameterInfo } );

				// System settings need evaluated prior to expressions!
				evaluateSystemSettings( parameterInfo );
				evaluateExpressions( parameterInfo );

				// Combine params like command foo:bar=1 foo:baz=2 foo:bum=3
				combineColonParams( parameterInfo );

				// Create globbing patterns
				createGlobs( parameterInfo, commandParams );

				// Ensure supplied params match the correct type
				validateParams( parameterInfo.namedParameters, commandParams );

				interceptorService.announceInterception( 'preCommand', { commandInfo=commandInfo, parameterInfo=parameterInfo } );

				// Run the command
				var result = commandInfo.commandReference.CFC.run( argumentCollection = parameterInfo.namedParameters );
				lastCommandErrored = commandInfo.commandReference.CFC.hasError();

			} catch( any e ){

				FRTransService.errorTransaction( FRTrans, e.getPageException() );
				lastCommandErrored = true;
				// If this command didn't already set a failing exit code...
				if( commandInfo.commandReference.CFC.getExitCode() == 0 ) {

					// Go ahead and set one for it.  The shell will inherit it below in the finally block.
					if( val( e.errorCode ?: 0 ) > 0 ) {
						commandInfo.commandReference.CFC.setExitCode( e.errorCode );
					} else {
						commandInfo.commandReference.CFC.setExitCode( 1 );
					}

				}

				var result = commandInfo.commandReference.CFC.getResult();
				// Add the command output thus far into the exception
				var originalInfo = '';
				if( len( result ) ) {
					originalInfo = e.extendedInfo
					e.extendedInfo=serializeJSON( {
						'extendedInfo'=originalInfo,
						'commandOutput'=result
					} );
				}

				// This is a little hacky,  but basically if there are more commands in the chain that need to run,
				// just print an exception and move on.  Otherwise, throw so we can unwrap the call stack all the way
				// back up.  That is necessary for command expressions that fail like "echo `cat noExists.txt`"
				// since in that case I don't want to execute the "echo" command since the "cat" failed.
				if( arrayLen( commandChain ) > i && listFindNoCase( '||,;', commandChain[ i+1 ].originalLine ) ) {

					// Dump out anything the command had printed so far
					if( len( result ) ){
						shell.printString( result & cr );
					}

					// These are "expected" exceptions like validation errors that can be "pretty"
					if( e.type.toString() == 'commandException' ) {
						shell.printError( { message : e.message, detail: e.detail, extendedInfo : e.extendedInfo ?: '' } );
					// These are catastrophic errors that warrant a full stack trace.
					} else {
						shell.printError( e );
					}
				// Unwind the stack to the closest catch
				} else {

					if( !captureOutput && len( result ) ) {
						// Dump out anything the command had printed so far
						shell.printString( result & cr );
						// If we're printing it now, remove it from the exception so the shell doesn't double-print it.
						e.extendedInfo=originalInfo;

					}
					throw e;
				}
			} finally {
				// Remove it from the stack
				instance.callStack.deleteAt( 1 );
				// Set command exit code into the shell
				shell.setExitCode( commandInfo.commandReference.CFC.getExitCode() );

				FRTransService.endTransaction( FRTrans );
			}

			// If the command didn't return anything, grab its print buffer value
			if( isNull( result ) ){
				local.result = commandInfo.commandReference.CFC.getResult();
				// Wipe out what's in there now that we have it
				commandInfo.commandReference.CFC.reset();
			}
			var interceptData = {
				commandInfo=commandInfo,
				parameterInfo=parameterInfo,
				result=result
			};
			interceptorService.announceInterception( 'postCommand', interceptData );
			local.result = interceptData.result;
			captureOutput = captureOutputOriginal;

		} // End loop over command chain

		return local.result;

	}

	/**
	* Generate a smart list of possible commands that the user meant to type
	*/
	function generateListOfSimilarCommands( required struct commandInfo ) {
		var allCommands = getCommands().keyArray().map( function( i ) { return lcase( listChangeDelims( i, ' ', '.' ) ); } );
		var matchedSoFar = lcase( listChangeDelims( arguments.commandInfo.commandString, ' ', '.' ) );
		var originalLine = arguments.commandInfo.originalLine;
		var candidates = [];

		for( var option in allCommands ) {
			// If we matched a partial command, only consider commands starting with that match
			if( len( matchedSoFar ) && !option.startsWith( matchedSoFar ) ) {
				continue;
			}
			// Ignore help commands
			if( listLast( option, ' ' ) == 'help' ) {
				continue;
			}
			var thisOriginalLine = originalLine;
			// Try to ignore params
			if( listLen( option, ' ' ) < listLen( originalLine, ' ' ) ) {
				thisOriginalLine = originalLine.listToArray( ' ' ).slice( 1, listLen( option, ' ' ) ).toList( ' ' );

			}
			var comparison = stringDistance.stringSimilarity( option, thisOriginalLine, 2 );
			if( comparison.similarity > .80 ) {
				candidates.append( '     ' & option );
			}
		}

		var helpText = '';
		if( arrayLen( candidates ) ) {
			helpText &= '#chr( 10 )#Did you mean: #chr( 10 )##candidates.toList( chr( 10 ) )##chr( 10 )#';
		}
		helpText &= '#chr( 10 )#Please type "#trim( "help #matchedSoFar#" )#" for assistance.';
		return helpText;
	}


	/**
	* Evaluates any expressions as a command string and puts the output in its place.
	*/
	function evaluateExpressions( required parameterInfo ) {

		// For each parameter being passed into this command
		for( var paramName in parameterInfo.namedParameters ) {

			var paramValue = parameterInfo.namedParameters[ paramName ];
			// Look for an expression "foo" flagged as "__expression__foo__expression__"
			var search = reFindNoCase( '__expression__.*?__expression__', paramValue, 1, true );

			// As long as there are more expressions
			while( search.pos[1] ) {
				// Extract them
				var expression = mid( paramValue, search.pos[1], search.len[1] );
				// Evaluate them (and capture output of any "run" command
				var result = runCommandline( mid( expression, 15, len( expression )-28 ), true ) ?: '';

				// Clean off trailing any CR to help with piping one-liner outputs as inputs to another command
				if( result.endsWith( chr( 10 ) ) && len( result ) > 1 ){
					result = left( result, len( result ) - 1 );
				}

				// And stick their results in their place
				parameterInfo.namedParameters[ paramName ] = replaceNoCase( paramValue, expression, result, 'one' );
				paramValue = parameterInfo.namedParameters[ paramName ];
				// Search again
			var search = reFindNoCase( '__expression__.*?__expression__', paramValue, 1, true );
			}
		}
	}


	/**
	* Evaluates any system settings and puts the output in its place.
	*/
	function evaluateSystemSettings( required parameterInfo ) {

		// For each parameter being passed into this command
		for( var paramName in parameterInfo.namedParameters ) {

			var paramValue = parameterInfo.namedParameters[ paramName ];
			// Look for a system setting "foo" flagged as "__system__foo__system__"
			var search = reFindNoCase( '__system__.*?__system__', paramValue, 1, true );

			// As long as there are more system settings
			while( search.pos[1] ) {
				// Extract them
				var systemSetting = mid( paramValue, search.pos[1], search.len[1] );
				// Evaluate them
				var settingName = mid( systemSetting, 11, len( systemSetting )-20 );
				var defaultValue = '';
				if( settingName.listLen( ':' ) ) {
					defaultValue = settingName.listRest( ':' );
					settingName = settingName.listFirst( ':' );
				}

				var result = systemSettings.getSystemSetting( settingName, defaultValue, parameterInfo.namedParameters );

				// And stick their results in their place
				parameterInfo.namedParameters[ paramName ] = replaceNoCase( paramValue, systemSetting, result, 'one' );
				paramValue = parameterInfo.namedParameters[ paramName ];
				// Search again
				var search = reFindNoCase( '__system__.*?__system__', paramValue, 1, true );
			}
		}
	}

	/**
	* Look through named parameters and combine any ones with a colon based on matching prefixes.
	*/
	function combineColonParams( required struct parameters ) {
		// Check each param
		for( var key in parameters.namedParameters.keyArray() ) {
			// If the name contains a colon, then break it out into a struct
			if( key contains ':' ) {
				// Default struct name for :foo=bar
				if( key.listLen( ':' ) > 1 ) {
					var prefix = key.listFirst( ':' );
					var nestedKey = key.listRest( ':' );
				} else {
					var prefix = 'args';
					var nestedKey = mid( key, 2, len( key ) );
				}
				// Default to empty struct if this is the first param with this prefix
				parameters.namedParameters[ prefix ] = parameters.namedParameters[ prefix ] ?: {};
				// Set the part after the colon as the key in the new struct.
				parameters.namedParameters[ prefix ][ nestedKey ] = parameters.namedParameters[ key ];
				// Remove original param
				parameters.namedParameters.delete( key );
			}
		}
	}

	/**
	 * Take an array of parameters and parse them out as named or positional
	 * @parameters The array of params to parse.
	 * @commandParameters valid params defined by the command
 	 **/
	function parseParameters( parameters, commandParameters ){
		return parser.parseParameters( parameters, commandParameters );
	}

	/**
	 * Figure out what command to run based on the user input string
	 * @line A string containing the command and parameters that the user entered
 	 **/
	function resolveCommand( required string line, boolean forCompletion=false ){
		// Turn the users input into an array of tokens
		var tokens = parser.tokenizeInput( line );

		return resolveCommandTokens( tokens, line, forCompletion );
	}

	/**
	 * Figure out what command to run based on the tokenized user input
	 * @tokens An array containing the command and parameters that the user entered
 	 **/
	function resolveCommandTokens( required array tokens, string rawLine=tokens.toList( ' ' ), boolean forCompletion=false ){

		// This will hold the command chain. Usually just a single command,
		// but a pipe ("|") will chain together commands and pass the output of one along as the input to the next
		var commandsToResolve = breakTokensIntoChain( tokens );
		rawLine = expandAliasesinRawLine( rawLine );
		var commandChain = [];

		// command hierarchy
		var cmds = getCommandHierarchy();
		var helpTokens = 'help,?,/?';
		var stopProcessingLine = false;
		var receivingPiped = false;

		for( var commandTokens in commandsToResolve ){

			tokens = commandTokens;
			var originalLine = tokens.toList( ' ' );

			// If command ends with "help", switch it around to call the root help command
			// Ex. "coldbox help" becomes "help coldbox"
			// Don't do this if we're already in a help command or endless recursion will ensue.
			if( tokens.len() > 1 && listFindNoCase( helpTokens, tokens.last() ) && !tokens[1].startsWith('!') && !inCommand( 'help' ) ){
				// Move help to the beginning
				tokens.deleteAt( tokens.len() );
				tokens.prepend( 'help' );
			}

			// If the first token looks like a drive letter, then it's just a Windows user trying to "cd" to a different drive
			// A drive letter for these purposes will be defined as up to 3 letters followed by a colon and an optional slash.
			if( tokens.len() && reFind( '^[a-z,A-Z]{1,3}:[\\,/]?$', tokens[1] ) ){
				var drive = tokens[1];
				// make sure the drive letter ends with a slash
				if( !( drive.endsWith( '\' ) || drive.endsWith( '/' ) ) ){
					drive &= '\';
				}
				// This is the droid you're looking for
				tokens = [ 'cd', drive ];
			}

			// Shortcut for "run" command if first token starts with !
			if( tokens.len() && len( tokens[1] ) > 1 && tokens[1].startsWith( '!' ) ) {
				// Trim the ! off
				tokens[1] = right( tokens[1], len( tokens[1] ) - 1 );
				// tack on "run"
				tokens.prepend( 'run' );
			} else if( tokens.len() && tokens[1] == '!' ) {
				tokens[1] = 'run' ;
			}

			/* If command is "run", merge all remaining tokens into one string
			*
			* run cmd /c dir
			* would essentially be turned into
			* run "cmd /c dir"
			 */
			 if( tokens.len() > 1 && tokens.first() == 'run'  ) {
				var tokens2 = tokens[ 2 ];
				// Escape any regex metacharacters in the pattern
				tokens2 = replace( tokens2, '\', '\\', 'all' );
				tokens2 = replace( tokens2, '.', '\.', 'all' );
				tokens2 = replace( tokens2, '(', '\(', 'all' );
				tokens2 = replace( tokens2, ')', '\)', 'all' );
				tokens2 = replace( tokens2, '^', '\^', 'all' );
				tokens2 = replace( tokens2, '$', '\$', 'all' );
				tokens2 = replace( tokens2, '|', '\|', 'all' );
				tokens2 = replace( tokens2, '+', '\+', 'all' );
				tokens2 = replace( tokens2, '{', '\{', 'all' );
				tokens2 = replace( tokens2, '}', '\}', 'all' );
				tokens2 = replace( tokens2, '*', '\*', 'all' );

				if( rawLine.reFindNoCase( '^(.*?)?[\s]*(run |!)[\s]*(#tokens2#.*)$' ) ) {
				 	tokens = [
				 		'run',
				 		// Strip off "!" or "run" at the start of the raw line.
				 		// TODO: this line will fail:
				 		//   echo "!git status" && !git status
				 		// Because we don't know where in the rawLine our current place in the command chain starts
				 		// To fix it though I'd need to substantially change how tokenizing works
				 		rawLine.reReplaceNoCase( '^(.*?)?[\s]*(run |!)[\s]*(#tokens2#.*)', '\3' )
				 	];
				} else {
				 	tokens = [
				 		'run',
				 		// As a fall back, if we receive the input from the commandline as a single string AND the quotes
				 		// don't follow what CommandBox's parser expects, we can't use the tokens array so we make the assumption
				 		// That the run command was the only command in the raw line.
				 		rawLine.reReplaceNoCase( '^[\s]*(run |!)[\s]*', '' )
				 	];
				}

			 	// The run command "eats" end entire rest of the line, so stop processing the command chain.
				stopProcessingLine = true;
			 }

			// Shortcut for "cfml" command if first token starts with #
			if( tokens.len() && len( tokens[1] ) > 1 && tokens[1].startsWith( '##' ) ) {
				// Trim the # off
				tokens[1] = right( tokens[1], len( tokens[1] ) - 1 );

				// If it looks like we have named params, convert the "name" to be named
				if( tokens.len() > 1 && parser.parseParameters( [ tokens[2] ], [] ).namedParameters.count() ) {
					tokens[1] = 'name=' & tokens[1];
				}

				// tack on "cfml"
				tokens.prepend( 'cfml' );
			}

			var results = {
				originalLine = originalLine,
				commandString = '',
				commandReference = cmds,
				parameters = [],
				found = false,
				closestHelpCommand = 'help'
			};

			var pos = 0;
			for( var token in tokens ){
				pos++;

				// If we hit a dead end, then quit looking
				if( !structKeyExists( results.commandReference, token ) ){
					break;
				}

				// If this is for command tab completion, don't select the command if there are two commands at the same level that start with this string
				// This check only runs if we've matched all the entered tokens and there is no trailing space.
				if( forCompletion && pos == tokens.len() ) {
					if( results.commandReference
						.keyArray()
						.filter( function( i ){
							return i.lcase().startsWith( token.lcase() );
						} )
						.len() > 1 ) {
							break;
						}
				}

				// Move the pointer
				results.commandString = listAppend( results.commandString, token, '.' );
				results.commandReference = results.commandReference[ token ];

				// If we've reached a command, we're done
				if( structKeyExists( results.commandReference, '$' ) ){
					results.found = true;

					// Actual command data stored in a nested struct
					results.commandReference = results.commandReference[ '$' ];

					// Create the command CFC instance if necessary
					lazyLoadCommandCFC( results.commandReference );

					break;
				// If this is a folder, check and see if it has a "help" command
				} else {
					if( structKeyExists( results.commandReference, 'help' ) && structKeyExists( results.commandReference.help, '$' ) ){
						results.closestHelpCommand = listChangeDelims( results.commandString, ' ', '.' ) & ' help';
					}
				}


			} // end for loop

			// If we found a command, carve the parameters off the end
			var commandLength = listLen( results.commandString, '.' );
			var tokensLength = arrayLen( tokens );
			if( results.found && commandLength < tokensLength ){
				results.parameters = tokens.slice( commandLength+1 );
			}

			commandChain.append( results );

			// Quit here if we're done with this command line
			if( stopProcessingLine ) {
				break;
			}

			receivingPiped = false;
			if( tokens.len() >= 1 && tokens[1] == '|' ) {
				receivingPiped = true;
			}

		} // end loop over commands to resolve

		// Return command chain
		return commandChain;

	}

	/**
	* Takes a single array of tokens and breaks it into a chain of commands (array of arrays)
	* i.e. foo bar | baz turns into [ [ 'foo', 'bar' ], [ '|' ], [ 'baz' ] ]
	*/
	private function breakTokensIntoChain( required array tokens ) {

		var commandsToResolve = [[]];
		var expandedCommandsToResolve = [];

		// If this command has a pipe, we need to chain multiple commands
		var i = 0;
		for( var token in tokens ){
			i++;
			// We've reached a pipe and there is at least one command resolved already and there are more tokens left
			if( token == '|' &&  commandsToResolve[ commandsToResolve.len() ].len() && i < tokens.len()  ){
				// Add a new command
				commandsToResolve.append( [ '|' ] );
				commandsToResolve.append( [] );
			} else if( token == ';' &&  commandsToResolve[ commandsToResolve.len() ].len() && i < tokens.len()  ){
				// Add a new command
				commandsToResolve.append( [ ';' ] );
				commandsToResolve.append( [] );
			} else if( token == '&&' &&  commandsToResolve[ commandsToResolve.len() ].len() && i < tokens.len()  ){
				// Add a new command
				commandsToResolve.append( [ '&&' ] );
				commandsToResolve.append( [] );
			} else if( token == '||' &&  commandsToResolve[ commandsToResolve.len() ].len() && i < tokens.len()  ){
				// Add a new command
				commandsToResolve.append( [ '||' ] );
				commandsToResolve.append( [] );
			} else if( token == '>' &&  commandsToResolve[ commandsToResolve.len() ].len() && i < tokens.len()  ){
				// Add a new command
				commandsToResolve.append( [ '|' ] );
				commandsToResolve.append( [ 'fileWrite' ] );
			} else if( token == '>>' &&  commandsToResolve[ commandsToResolve.len() ].len() && i < tokens.len()  ){
				// Add a new command
				commandsToResolve.append( [ '|' ] );
				commandsToResolve.append( [ 'fileAppend' ] );
			} else if( !listFindNoCase( '|,;,>,>>,&&', token ) ) {
				//Append this token to the last command
				commandsToResolve[ commandsToResolve.len() ].append( token );
			}
		}

		// Expand aliases
		for( var commandTokens in commandsToResolve ) {
			var originalLine = commandTokens.toList( ' ' );
			var aliases = configService.getSetting( 'command.aliases', {} );
			var matchingAlias = '';

			for( var alias in aliases ) {
				if( lcase( originalLine ).startsWith( lcase( alias ) ) ) {
					matchingAlias = alias;
					break;
				}
			}

			// If the exact tokens in this command match an alias, swap it out.
			if( matchingAlias.len() ) {
				expandedCommandsToResolve.append(
					// Recursively dig down. This allows aliases to alias other alises
					breakTokensIntoChain(
						// Re-tokenize the new string
						parser.tokenizeInput(
							// Expand the alias with the string it aliases
							replaceNoCase( originalLine, matchingAlias, aliases[ matchingAlias ], 'once' )
						)
					 ),
				true );
			// Otherwise just use them as is.
			} else {
				expandedCommandsToResolve.append( commandTokens );
			}

		}
		return expandedCommandsToResolve;
	}


	/**
	 * Replaces aliases in the raw line
 	 **/
	private function expandAliasesinRawLine( string rawLine ) {
		var aliases = configService.getSetting( 'command.aliases', {} );
		var matchingAlias = '';

		for( var alias in aliases ) {
			if( lcase( rawLine ).startsWith( lcase( alias ) ) ) {
				matchingAlias = alias;
				break;
			}
		}

		// If the start of this command matches an alias, swap it out.
		if( matchingAlias.len() ) {
			// Recursively dig down. This allows aliases to alias other alises
			return expandAliasesinRawLine(
					// Expand the alias with the string it aliases
					replaceNoCase( rawLine, matchingAlias, aliases[ matchingAlias ], 'once' )
			 );
		}

		return rawLine;
	}

	/**
	 * Takes a struct of command data and lazy loads the actual CFC instance if necessary
	 * @commandData Struct created by registerCommand()
 	 **/
	private function lazyLoadCommandCFC( commandData ){

		// Check for actual CFC instance, and lazy load if necessary
		if( !structKeyExists( commandData, 'CFC' ) ){
			// Create this command CFC
			try {

				// Check if command mapped?
				if( NOT wirebox.getBinder().mappingExists( "command-" & commandData.fullCFCPath ) ){
					// feed this command to wirebox with virtual inheritance
					wirebox.registerNewInstance( name="command-" & commandData.fullCFCPath, instancePath=commandData.fullCFCPath )
						.setScope( wirebox.getBinder().SCOPES.SINGLETON )
						.setThreadSafe( true )
						.setVirtualInheritance( "commandbox.system.BaseCommand" );
				}
				// retrieve, build and wire from wirebox
				commandData.CFC = wireBox.getInstance( "command-" & commandData.fullCFCPath );

			// This will catch nasty parse errors so the shell can keep loading
			} catch( any e ){
				// Log the full exception with stack trace
				logger.error( 'Error creating command [#commandData.fullCFCPath#]. #e.message# #e.detail ?: ''#', e.stackTrace );
				shell.setExitCode( 1 );
				throw( message='Error creating command [#commandData.fullCFCPath#]', detail="#e.message# #CR# #e.detail ?: ''# #CR# #e.stacktrace#", type="commandException");
			}
		} // CFC exists check
		return true;
	}

	/**
	 * Looks at the call stack to determine if we're currently "inside" a command.
	 * Useful to prevent endless recursion.
	 * @command Name of the command to look for as typed from the shell.  If empty, returns true for any command
 	 **/
	function inCommand( command='' ){

		// If a command is provided, look for it in the call stack..
		if( len( command ) ){
			for( var call in instance.callStack ){
				// CommandString is a dot-delimited path
				if( call.commandInfo.commandString == listChangeDelims( command, ' ', '.' ) ){
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
	 * return a list of base commands
 	 **/
	function listCommands(){
		return structKeyList( instance.flattenedCommands );
	}

	/**
	 * return the command structure
 	 **/
	function getCommands(){
		return instance.flattenedCommands;
	}

	/**
	 * return the nested command structure
 	 **/
	function getCommandHierarchy(){
		return instance.Commands;
	}

	/******************************************* PRIVATE ***************************************/

	/**
	 * load command CFC
	 * @baseCommandDirectory The base directory for this command
	 * @cfc CFC name that represents the command
	 * @commandPath The relative dot-delimited path to the CFC starting in the commands dir
	 **/
	private function registerCommand( baseCommandDirectory, CFC, commandPath ){

		// Strip cfc extension from filename
		var CFCName = mid( CFC, 1, len( CFC ) - 4 );
		var commandName = iif( len( commandPath ), de( commandPath & '.' ), '' ) & CFCName;
		// Build CFC's path
		var fullCFCPath = baseCommandDirectory & '.' & commandName;


		try {
			// Create a nice struct of command metadata
			var commandData = createCommandData( fullCFCPath, commandName );
		// This will catch nasty parse errors so the shell can keep loading
		} catch( any e ){
			shell.printString( 'Error registering command [#fullCFCPath#]#cr#' );
			logger.error( 'Error registering command [#fullCFCPath#]. #e.message# #e.detail ?: ''#', e.stackTrace );
			// pretty print the exception
			 shell.printError( e );
			return;
		}

		// must be CommandBox CFC, can't be Application.cfc
		if( CFCName == 'Application' || !isCommandCFC( commandData ) ){
			return;
		}

		// Add it to the command dictionary
		addToDictionary( commandData, commandPath & '.' & CFCName );

		// Register the aliases
		for( var alias in commandData.aliases ){
			// Alias is allowed to be anything.  This means it may even overwrite another command already loaded.
			addToDictionary( commandData, listChangeDelims( trim( alias ), '.', ' ' ) );
		}
	}

	/**
	 * Remove a command from memory
	 * @baseCommandDirectory The base directory for this command
	 * @cfc CFC name that represents the command
	 * @commandPath The relative dot-delimited path to the CFC starting in the commands dir
	 **/
	private function removeCommand( baseCommandDirectory, CFC, commandPath ){

		// Strip cfc extension from filename
		var CFCName = mid( CFC, 1, len( CFC ) - 4 );
		var commandName = iif( len( commandPath ), de( commandPath & '.' ), '' ) & CFCName;
		// Build CFC's path
		var fullCFCPath = baseCommandDirectory & '.' & commandName;


		try {
			// Create a nice struct of command metadata
			var commandData = createCommandData( fullCFCPath, commandName );
		// This will catch nasty parse errors so the shell can keep loading
		} catch( any e ){
			shell.printString( 'Error loading command data [#fullCFCPath#]#cr#' );
			logger.error( 'Error loading command data [#fullCFCPath#]. #e.message# #e.detail ?: ''#', e.stackTrace );
			// pretty print the exception
			 shell.printError( e );
			return;
		}

		// must be CommandBox CFC, can't be Application.cfc
		if( CFCName == 'Application' || !isCommandCFC( commandData ) ){
			return;
		}

		// Add it to the command dictionary
		removeFromDictionary( commandData, commandPath & '.' & CFCName );

		// Register the aliases
		for( var alias in commandData.aliases ){
			// Alias is allowed to be anything.  This means it may even overwrite another command already loaded.
			removeFromDictionary( commandData, listChangeDelims( trim( alias ), '.', ' ' ) );
		}
		var mappingName = "command-" & fullCFCPath;
		wirebox.getScope( 'singleton' ).getSingletons().delete( mappingName );
	}

	/**
	* Create command metadata
	* @fullCFCPath the full CFC path
	* @commandName the command name
	*/
	private struct function createCommandData( required fullCFCPath, required commandName ){
		// Get from cache or produce on demand
		var commandMD = metadataCache.getOrSet(
			fullCFCPath,
			function() {
				return wirebox.getUtil().getInheritedMetaData( fullCFCPath );
			}
		);

		// Set up of command data
		var commandData = {
			fullCFCPath 	= arguments.fullCFCPath,
			aliases 		= listToArray( commandMD.aliases ?: '' ),
			parameters 		= [],
			completor 		= {},
			hint 			= commandMD.hint ?: '',
			originalName 	= commandName,
			excludeFromHelp = commandMD.excludeFromHelp ?: false,
			commandMD 		= commandMD
		};

		// Fix for CFCs with no hint, they inherit this from the Lucee base component.
		if( commandData.hint == 'This is the Base Component' ) {
			commandData.hint = '';
		}

		// check functions
		if( structKeyExists( commandMD, 'functions' ) ){
			// Capture the command's parameters
			for( var func in commandMD.functions ){
				// Loop to find the "run()" method
				if( func.name == 'run' ){
					commandData.parameters = func.parameters;
					// Grab completor annotations if they exists while we're here
					// We'll save these out in a struct indexed by param name for easy finding
					for( var param in func.parameters ){
						if( structKeyExists( param, 'options' ) ){
							// Turn comma-delimited list of static values into an array
							commandData.completor[ param.name ][ 'options' ] = listToArray( param.options );
						}
						if( structKeyExists( param, 'optionsUDF' ) ){
							// Grab name of completor function for this param
							commandData.completor[ param.name ][ 'optionsUDF' ] = param.optionsUDF;
						}
						// Check for directory or file path completion
						// File completion inherently includes directories, so no need for both.
						if( structKeyExists( param, 'optionsFileComplete' ) && param.optionsFileComplete ){
							commandData.completor[ param.name ][ 'optionsFileComplete' ] = param.optionsFileComplete;
						} else if( structKeyExists( param, 'optionsDirectoryComplete' ) && param.optionsDirectoryComplete ){
							commandData.completor[ param.name ][ 'optionsDirectoryComplete' ] = param.optionsDirectoryComplete;
						}
					}

					break;
				}
			}
		} else {
			commandData.parameters = [];
		}

		return commandData;
	}

	/**
	* checks if given cfc name is a valid command component
	* @commandData the command metadata
	*/
	function isCommandCFC( required struct commandData ){
		var meta = arguments.commandData.commandMD;

		// Make sure command has a run() method
		for( var func in meta.functions ?: [] ){
			// Loop to find the "run()" method
			if( func.name == 'run' ){
				return true;
			}
		}

		// Didn't find run() method
		return false;
	}

	/**
	 * Make sure we have all required params
 	 **/
	function ensureRequiredparams( userNamedParams, commandParams ){
		// For each command param
		for( var param in commandParams ){
			// If it's required and hasn't been supplied...
			if( param.required && !structKeyExists( userNamedParams, param.name ) ){
				// ... Ask the user
				var message = 'Enter #param.name# ';
				var value  	= "";
				// Verify hint
				if( structKeyExists( param, 'hint' ) ){
					message &= '(#param.hint#) ';
				}
				message &= ':';
				// ask value logic
				var askValue = function(){
					// Is this a boolean value
					if( structKeyExists( param, "type" ) and param.type == "boolean" ){
						return shell.confirm( message & "(Yes/No)" );
					}
					// Strings
					else {
						// If the param name contains the word "password", then mask the input.
						return shell.ask( message, ( param.name contains 'password' ? '*' : '' ) );
					}
				};

				// Ask for value
				value = askValue();

           		// value entered matches the type!
           		userNamedParams[ param.name ] = value;
			}
		} // end for loop

		return userNamedParams;
	}

	/**
	 * Check for Globber parameters and create actual Globber object out of them
 	 **/
	private function createGlobs( parameterInfo, commandParams ) {
		// Loop over user-supplied params
		for( var paramName in parameterInfo.namedParameters ) {

			// If this is an expected param
			var functionIndex = commandParams.find( function( i ) {
				return i.name == paramName;
			} );

			if( functionIndex ) {
				var paramData = commandParams[ functionIndex ];
				// And it's of type Globber
				if( ( paramData.type ?: 'any' ) == 'Globber' ) {

					// Overwrite it with an actual Globber instance seeded with the original canonical path as the pattern.
					var originalPath = parameterInfo.namedParameters[ paramName ];
					var newPath = originalPath.listMap( (p) => {
						p = fileSystemUtil.resolvePath( p );
						// The globber won't match a dir if you include the trailing slash, so pull them off
						// This allows
						// > rm tests/
						// or
						// > touch tests
						// to affect the "tests" folder itself
						if( p.endsWith( '/' ) || p.endsWith( '\' ) ) {
							p = p.left(-1);
						}
						return p;
					} );

					parameterInfo.namedParameters[ paramName ] = wirebox.getInstance( 'Globber' )
						.setPattern( newPath );
				}
			}
		}
	}

	/**
	 * Make sure all params are the correct type
 	 **/
	private function validateParams( userNamedParams, commandParams ){
		// For each command param
		for( var param in commandParams ){
			// If it's required and hasn't been supplied...
			if( userNamedParams.keyExists( param.name )
				&& param.keyExists( "type" )
				&& param.type != 'Globber'
				&& !isValid( param.type, userNamedParams[ param.name ] ) ){

				shell.setExitCode( 1 );
				throw( message='Parameter [#param.name#] has a value of [#serialize( userNamedParams[ param.name ] )#] which is not of type [#param.type#].', type="commandException");
			}
		} // end for loop

		return true;
	}


	/**
	 * Match positional parameters up with their names
 	 **/
	function convertToNamedParameters( userPositionalParams, commandParams ){
		var results = [:];

		var i = 0;
		// For each param the user typed in
		for( var param in userPositionalParams ){
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
	 * Merge flags into named parameters
 	 **/
	private function mergeFlagParameters( required struct parameterInfo ) {
		// Add flags into named params
		arguments.parameterInfo.namedParameters.append( arguments.parameterInfo.flags );
	}

	/**
	 * Merge in parameter defaults
 	 **/
	private function addDefaultParameters( commandString, parameterInfo ) {
		// Get defaults for this command, an empty struct if nothing.
		var defaults = configService.getSetting( 'command.defaults["#commandString#"]', {} );
		var params = parameterInfo.namedParameters;

		// For each default
		defaults.each( function( k,v ) {
			// If it's not already set
			if( !params.keyExists( k ) ) {
				// Stick it in there!
				params[ k ] = v;
			}
		} );

	}


	/**
	 * Get the array of commands being executed.
	 * This may be empty.
 	 **/
	array function getCallStack() {
		return instance.callStack;
	}

}
