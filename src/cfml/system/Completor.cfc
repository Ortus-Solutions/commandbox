/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle tab completion in the shell
*
*/
component singleton {

	//DI
	property name="commandService" inject="CommandService";
	property name="fileSystemUtil" inject="FileSystem";
	property name='logger' inject='logbox:logger:{this}';
	property name='shell' inject='Shell';


	/**
	 * Constructor
	 **/
	function init() {
		return this;
	}

	/**
	 * populate completion candidates and return cursor position
	 * @buffer.hint text so far
	 * @cursor.hint cursor position
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	numeric function complete( String buffer, numeric cursor, candidates )  {

		try {

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
				var definedParameters = commandInfo.commandReference.parameters;
				// This is the params the user has entered so far.
				var passedParameters = commandService.parseParameters( commandInfo.parameters );

				// For sure we are using named- suggest name or value as necceessary
				if( structCount( passedParameters.namedParameters ) ) {

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

				// For sure positional - suggest next param name and value
				// Either there's more than one positional param supplied, or a single one with a space after it
				} else if(
							passedParameters.positionalParameters.len() > 1
							|| ( passedParameters.positionalParameters.len() == 1 && buffer.endsWith( ' ' ) )
						) {

					// If the buffer ends with a space, they were done typing the last param
					if( buffer.endsWith( ' ' ) ) {

						// If there are more params than what the user has typed so far
						if( definedParameters.len() > passedParameters.positionalParameters.len() ) {
							// Add the name of the next one in the list. The user will have to backspace and
							// replace this with their actual param so this may not be that useful.
							var nextParam = definedParameters[ passedParameters.positionalParameters.len()+1 ];
							candidates.add( nextParam.name & ' ' );

							paramValueCompletion( nextParam.type, nextParam.type, '', candidates );

							return len( buffer );

						} // End are there more params

					// They were in the middle of typing
					} else {

						// Make sure defined params actually exist for this
						if( definedParameters.len() >= passedParameters.positionalParameters.len() ) {

							var partialMatch = passedParameters.positionalParameters.last();
							var thisParam = definedParameters[ passedParameters.positionalParameters.len() ];
							paramValueCompletion( thisParam.name, thisParam.type, partialMatch, candidates );

							return len( buffer ) - len( partialMatch );
						}
					}

				// Too soon to tell - suggest first param name and first param value
				// There might me partially typed text, but there's no space at the end yet.
				} else {

					// Make sure defined params actually exist
					if( definedParameters.len() ) {

						var partialMatch = '';
						// If there is a passed positional param
						if( passedParameters.positionalParameters.len() ) {
							// grab the last one as the partial match
							partialMatch = passedParameters.positionalParameters.last();
						}

						// Loop over all possible params and suggest them
						for( var param in definedParameters ) {
							if( !len( partialMatch ) || param.name.startsWith( partialMatch ) ) {
								candidates.add( param.name & '=' );
							}
						}

						// Grab first param
						var thisParam = definedParameters[ 1 ];

						// Suggest its value
						paramValueCompletion( thisParam.name, thisParam.type, partialMatch, candidates );

						return len( buffer ) - len( partialMatch );

					}  // End are there params defined


				} // End what kind of params are we dealing with


			} // End was the command found

			return len( buffer );

		} catch ( any e ) {
			rethrow;
			// by default, errors thrown from proxied components are useless and don't have an actual stack trace.
			shell.printError( e );
			return 0;
		}
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
		
		paramName = lcase( paramName );
		if( paramName.startsWith( 'directory' ) || 
			paramName.startsWith( 'destination' ) ||
			paramName.endsWith( 'directory' ) ||
			paramName.endsWith( 'destination' ) 
		){
			pathCompletion( paramSoFar, candidates, false );			
		} else if( paramName.startsWith( 'file' ) || 
				   paramName.endsWith( 'file' ) || 
				   paramName.startsWith( 'path' ) ||
				   paramName.endsWith( 'path' ) 
		){
			pathCompletion( paramSoFar, candidates, true );
		}
	}

	/**
	 * Populate parameter value completion candidates
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
	 * @type.showFiles Whether to hit files as well as directories
 	 **/
	private function pathCompletion(String startsWith, required candidates, showFiles=true ) {
		// This is what we add to relative paths, with the slashes normalized
		var relativeRootPath = replace( shell.pwd() & '/', "\", "/", "all" );

		// Keep track of whether this is a relative path or not.
		var isRelative = false;

		// Note, I'm NOT using fileSystemUtil.resolvePath() here because I don't want the
		// path canoncalized since that will break my text comparisons.  Leave the ../ stuff in
		var oPath = createObject( 'java', 'java.io.File' ).init( arguments.startsWith );
		if( !oPath.isAbsolute() ) {
			isRelative = true;
			// If it's relative, we assume it's relative to the current working directory and make it absolute
			arguments.startsWith = 	relativeRootPath & arguments.startsWith;
		}

		// This is out absolute directory as typed by the user
		startsWith = replace( startsWith, "\", "/", "all" );
		// searchIn strips off partial directories, and has the last complete actual directory for searching.
		var searchIn = startsWith;
		// This is the bit at the end that is a partially typed directory or file name
		// Note, this can be an empty string!
		var partialMatch = '';
		// If we aren't already pointing to the root of a real directory, peel the path back to the dir
		if( right( searchIn, 1 ) != '/' ) {
			searchIn = getDirectoryFromPath( searchIn );
			// If we stripped back to a directory, take what is left as the partial match
			if( startsWith.len() > searchIn.len() ) {
				partialMatch = replaceNoCase( startsWith, searchIn, '' );
			}
		}

		// Don't even bother if search location doesn't exist
		if( directoryExists( searchIn ) ) {
			// Pull a list of paths in there
			var paths = directoryList( path=searchIn, listInfo='query' );

			for( var path in paths ) {

				// Leave original case in path, we'll lowercase it on Windows
				var thisName = path.name;
				if( server.os.name contains 'Windows' ) {
					partialMatch = lcase( partialMatch );
					thisName = lcase( path.name );
				}

				// This comparison will be case-sensitive on Mac and Linux/
				if( thisName.startsWith( partialMatch ) ) {
					// Do we care about this type?
					if( arguments.showFiles == true || path.type == 'dir' ) {

						// This is the absolute path that we matched
						var thisCandidate = searchIn & ( right( searchIn, 1 ) == '/' ? '' : '/' ) & path.name;

						// If we started with a relative path...
						if( isRelative ) {
							// ...strip it back down to what they typed
							thisCandidate = replaceNoCase( thisCandidate, relativeRootPath, '' );
						}
						// Finally add this candidate into the list
						candidates.add( thisCandidate & ( path.type == 'dir' ? '/' : '' ) );
					}
				}
			} // End path loop
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