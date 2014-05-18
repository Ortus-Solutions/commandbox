/**
 * completion handler
 * @author Denny Valliant
 **/
component output="false" persistent="false" {

	// command list
	commandlist = createObject("java","java.util.TreeSet");

	/**
	 * constructor
	 * @commandService.hint CommandService this completor is attached to
	 **/
	function init(commandService) {
		variables.commandService = arguments.commandService;
		variables.commandlist.addAll(commandService.listCommands().split(','));
		variables.commands = commandService.getCommands();
	}

	/**
	 * populate completion candidates and return cursor position
	 * @buffer.hint text so far
	 * @cursor.hint cursor position
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	function complete( String buffer, numeric cursor, candidates )  {
		var buffer = buffer ?: "";
		// Try to resolve the command.
		var commandChain = commandService.resolveCommand( buffer );
		// If there are multiple commands like "help | more", we only care about the last one
		var commandInfo = commandChain[ commandChain.len() ];
									
		// Positive match up to this cursor position
		var matchedToHere = len( commandInfo.commandString );
		// Partial text that didn't match anything
		var leftOver = '';
		
		// If stuff was typed and it's an exact match to a command part
		if( matchedToHere == len( buffer ) && len( buffer ) ) {
			// Suggest a trailing space
			candidates.add( buffer & ' ' );
			return 0;
		// Everything else in the buffer is a partial, unmached command
		} else if( len( buffer ) ) {
			// This is the unmatched stuff
			leftOver = right( buffer, len( buffer ) - matchedToHere );
			// If there was space, then account for that 
			if( left( leftOver, 1 ) == ' ' ) {
				leftOver = trim( leftOver );
				matchedToHere++;
			}
		}
										
		// Didn't match an exact command, but might have matched part of one.
		if( !commandInfo.found ) {
						
			// Loop over all the possibilities at this level
			for( var command in commandInfo.commandReference ) {
				// Match the partial bit if it exists
				if( !len( leftOver ) || command.startsWith( leftOver ) ) {
					// Add extra space so they don't have to
					candidates.add( command & ' ' );	
				}	
			}
			
			// Did we find ANYTHING?
			if( candidates.size() ) {
				return matchedToHere;				
			} else {
				return len( buffer );
			}
			
			
		// If we DID find a command and it's followed by a space, then suggest parameters
		} else {
			// This is all the possible params for the command
			var definedParameters = commandInfo.commandReference.$CommandBox.parameters;
			// This is the params the user has entered so far.
			var passedParameters = commandService.parseParameters( commandInfo.parameters );
										
			// Is the user using positional params
			if( arrayLen( passedParameters.positionalParameters ) > 1  ) {
				
				// If there are more params than what the user has typed so far
				if( definedParameters.len() > passedParameters.positionalParameters.len() ) {
					// Add the name of the next one in the list. The user will have to backspace and 
					// replace this with their actual param so this may not be that useful. 
					// TODO: This is useful because if the user is using positional parameters it reminds them 
					// of what comes next, however, I'm not sure I like it because it means we can't do type-based
					// auto-complete for directories and such.  Figure out which one we want more and do that.
					candidates.add( definedParameters[ passedParameters.positionalParameters.len()+1 ].name & ' ' );
				}
				return len( buffer );
				
			// Using named params (default)
			} else {
								
				var leftOver = '';
				// This is probably just partial param name
				if( arrayLen( passedParameters.positionalParameters ) ) {
					leftOver = passedParameters.positionalParameters[ passedParameters.positionalParameters.len() ];
				// If there's at least one named param, and we don't end with a space, assume we're still typing it
				} else if( structCount( passedParameters.namedParameters ) && !buffer.endsWith( ' ' ) ) {
					// If param= is typed, but no value
					if( buffer.endsWith( '=' ) ) {
						// Nothign here
						var paramSoFar = '';
						// Strip = sign, and grab preceeding param name
						var paramName = listLast( trim( left( buffer, len( buffer ) - 1 ) ), ' ' );
						var startHere = len( buffer );						
					} else {
						// param so far is everything after the last =
						var paramSoFar = listLast( buffer, '=' );
						// Delete that off, and take the preceeding param name
						var paramName = listLast( trim( listDeleteAt( buffer, listLen( buffer, '=' ), '=' ) ), ' ' );						
					}
					var paramType = '';
					// Now that we have the name, see if we can look up the type
					for( var param in definedParameters ) {
						if( param.name == paramName ) {
							paramType = param.type;
							break;							
						}
					}
					// Fill in possible param values based on the type and contents so far.
					paramValueCompletion( paramName, paramType, paramSoFar, candidates );
					return len( buffer ) - len( paramSoFar );
					
				}
				
				// Loop over all possible params and suggest the ones not already there
				for( var param in definedParameters ) {
					if( !structKeyExists( passedParameters.namedParameters, param.name ) ) {
						if( !len( leftOver ) || param.name.startsWith( leftOver ) ) {
							candidates.add( ' ' & param.name & '=' );
						}	
					}
				}
				
				// Back up a bit to the beginning of the left over text we're replacing
				return len( buffer ) - len( leftOver ) - iif( !len( leftOver ) && !buffer.endsWith( ' ' ), 0, 1 );
				
			} // End are we using positional params
			
			
		} // End was the command found
		
		return len( buffer );
	}

	/**
	 * populate completion candidates for parameter values
	 * @paramName.hint param name
	 * @paramType.hint type of parameter (boolean, etc.)
	 * @paramSoFar.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function paramValueCompletion(String paramName, String paramType, String paramSoFar, required candidates) {
		
		switch(paramType) {
			case "Boolean" :
           		addCandidateIfMatch("true ",paramSoFar,candidates);
           		addCandidateIfMatch("false ",paramSoFar,candidates);
				break;
		}
		switch(paramName) {
			case "directory" :
			case "destination" :
           		directoryCompletion(paramSoFar,candidates);
				break;
			case "file" :
           		fileCompletion(paramSoFar,candidates);
				break;
		}
	}

	/**
	 * populate directory parameter value completion candidates
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function directoryCompletion(String startsWith, required candidates) {
		startsWith = replace(startsWith,"\","/","all");
		if(startsWith == "") {
			startsWith = commandService.getShell().pwd();
		}
		var files = directoryList(getDirectoryFromPath(startsWith));
		for(file in files) {
			if(file.startsWith(startsWith)) {
				if(directoryExists(file))
					candidates.add(file&"/" & ' ');
			}
		}
	}


	/**
	 * populate file parameter value completion candidates
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function fileCompletion(String startsWith, required candidates) {
		
		if( startsWith == "" ) {
			startsWith = commandService.getShell().pwd() & '/';
		}
				
		startsWith = replace( startsWith, "\", "/", "all" );		
		var files = directoryList( getDirectoryFromPath( startsWith &  '/' ) );
		for(file in files) {
			file = replace( file, "\", "/", "all" );
			
			if(file.startsWith(startsWith)) {
				if(fileExists(file))
					candidates.add(file & ' ');
			}
		}
	}

	/**
	 * add a value completion candidate if it matches what was typed so far
	 * @match.hint text to compare as match
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function addCandidateIfMatch(required match, required startsWith, required candidates) {
		match = lcase(match);
		startsWith = lcase(startsWith);
		if(match.startsWith(startsWith) || len(startsWith) == 0) {
			candidates.add(match);
		}
	}

}