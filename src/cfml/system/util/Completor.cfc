/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
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
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	numeric function complete( reader, parsedLine, candidates )  {

		try {
			var javaCandidates = candidates;
			arguments.candidates = [];

			var buffer = parsedLine.line();
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
				arraySort( candidates, 'text' );
				
				createCandidates( candidates, javaCandidates );
				return;
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
					if( !len( leftOver ) || lcase( command ).startsWith( lcase( leftOver ) ) ) {
						// Add extra space so they don't have to
						candidates.add( command & ' ' );
					}
				}

				// Did we find ANYTHING?
				if( candidates.size() ) {
					arraySort( candidates, 'text' );
					// return matchedToHere;
					
					createCandidates( candidates, javaCandidates );
					return;
				} else {
					arraySort( candidates, 'text' );
					// return len( buffer );
					
					createCandidates( candidates, javaCandidates );
					return;
				}


			// If we DID find a command and it's followed by a space, then suggest parameters
			} else {
				// This is all the possible params for the command
				var definedParameters = commandInfo.commandReference.parameters;
				// This is the params the user has entered so far.
				var passedParameters = commandService.parseParameters( commandInfo.parameters, definedParameters );

				// For sure we are using named- suggest name or value as necceessary
				if( structCount( passedParameters.namedParameters ) ) {

					var leftOver = '';

					// Still typing
					if( !buffer.endsWith( ' ' ) ) {

						// grab the last chunk of text from the buffer
						var leftOver = listLast( buffer, ' ' );

						// value completion only
						if( leftOver contains '=' ) {

							// Param name is bit before the =
							var paramName = listFirst( leftOver, '=' );
							// Everything else, is the value so far
							var paramSoFar = '';
							// There's only a value if somethign was typed after the =
							if( !leftOver.endsWith( '=' ) ) {
								paramSoFar = listLast( leftOver, '=' );
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
							paramValueCompletion( commandInfo, paramName, paramType, paramSoFar, candidates, true );
							arraySort( candidates, 'text' );
							//return len( buffer ) - len( paramSoFar );
							
							createCandidates( candidates, javaCandidates );
							return;

						}


					} // End still typing?

					// Loop over all possible params and suggest the ones not already there
					for( var param in definedParameters ) {
						if( !structKeyExists( passedParameters.namedParameters, param.name ) && !structKeyExists( passedParameters.flags, param.name ) ) {
							if( !len( leftOver ) || lcase( param.name ).startsWith( lcase( leftOver ) ) ) {
								candidates.add( ' ' & param.name & '=' );
							}
							// If this is a boolean param, suggest the --flag version
							if( param.type == 'boolean' ) {
								var flagParamName = '--' & param.name;
								if( !len( leftOver ) || lcase( flagParamName ).startsWith( lcase( leftOver ) ) ) {
									candidates.add( ' ' & flagParamName & ' ' );
								}
							}
						} // Does it exist yet?
					} // Loop over possible params

					// Back up a bit to the beginning of the left over text we're replacing
					arraySort( candidates, 'text' );
					//return len( buffer ) - len( leftOver ) - iif( !len( leftOver ) && !buffer.endsWith( ' ' ), 0, 1 );
					
					createCandidates( candidates, javaCandidates );
					return;

				// For sure positional - suggest next param name and value
				// Either there's more than one positional param supplied, or a single one with a space after it
				// or a single one with flags present
				} else if(
							passedParameters.positionalParameters.len() > 1
							|| ( passedParameters.positionalParameters.len() == 1
								&& ( buffer.endsWith( ' ' ) || structCount( passedParameters.flags ) ) )
						) {

					// If the buffer ends with a space, they were done typing the last param
					if( buffer.endsWith( ' ' ) ) {

						// Loop over remaining possible params and suggest the boolean ones as flags
						var i = 0;
						for( var param in definedParameters ) {
							i++;
							// If this is a boolean param not already here, suggest the --flag version
							if( i > passedParameters.positionalParameters.len() && param.type == 'boolean' && !structKeyExists( passedParameters.flags, param.name )  ) {
								candidates.add( ' --' & param.name & ' ' );
							}
						}

						var i = 0;
						for( var param in definedParameters ) {
							i++;
							// For every param we haven't reached that doesn't exist as a flag
							if( i > passedParameters.positionalParameters.len() && !structKeyExists( passedParameters.flags, param.name )) {
								// Add the name of the next one in the list. The user will have to backspace and
								// replace this with their actual param so this may not be that useful.

								candidates.add( param.name & ' ' );
								paramValueCompletion( commandInfo, param.name, param.type, '', candidates, false );
								// Bail once we find one
								break;
							}
						}

						arraySort( candidates, 'text' );
						// return len( buffer );
						
						createCandidates( candidates, javaCandidates );
						return;


					// They were in the middle of typing
					} else {

						// Make sure defined params actually exist for this
						if( definedParameters.len() >= passedParameters.positionalParameters.len() ) {

							// If there is a passed positional param or flags
							if( passedParameters.positionalParameters.len() || structCount( passedParameters.flags ) ) {
								// grab the last chunk of text from the buffer
								var partialMatch = listLast( buffer, ' ' );
							}

							var thisParam = definedParameters[ passedParameters.positionalParameters.len() ];
							paramValueCompletion( commandInfo, thisParam.name, thisParam.type, partialMatch, candidates, false );

							// Loop over remaining possible params and suggest the boolean ones as flags
							var i = 0;
							for( var param in definedParameters ) {
								i++;
								// If this is a boolean param not already here, suggest the --flag version
								if( i >= passedParameters.positionalParameters.len() && param.type == 'boolean' && !structKeyExists( passedParameters.flags, param.name ) ) {
									var paramFlagname = '--' & param.name;
									if( lcase( paramFlagname ).startsWith( lcase( partialMatch ) ) ) {
										candidates.add( paramFlagname & ' ' );
									}
								}
							}

							arraySort( candidates, 'text' );
							// return len( buffer ) - len( partialMatch );
							
							createCandidates( candidates, javaCandidates );
							return;
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
						// If there are flags and the buffer doesn't end with a space, then we must still be typing one
						} else if( structCount( passedParameters.flags ) && !buffer.endsWith( ' ' ) ) {
							// grab the last chunk of text from the buffer
							partialMatch = listLast( buffer, ' ' );
						}

						// Loop over all possible params and suggest them
						for( var param in definedParameters ) {
							// If this param is not already a flag and it matches the partial text add it
							if( !structKeyExists( passedParameters.flags, param.name )  && ( !len( partialMatch ) || lcase( param.name ).startsWith( lcase( partialMatch ) ) ) ) {
								candidates.add( param.name & '=' );
							}

							// If this param is a boolean that isn't a flag yet, sugguest the --flag version
							var paramFlagname = '--' & param.name;
							if( param.type == 'boolean' && !structKeyExists( passedParameters.flags, param.name ) && lcase( paramFlagname ).startsWith( lcase( partialMatch ) ) ) {
								candidates.add( paramFlagname & ' ' );
							}
						}

						// Grab first param
						var thisParam = definedParameters[ 1 ];

						// Suggest its value
						paramValueCompletion( commandInfo, thisParam.name, thisParam.type, partialMatch, candidates, false );

						arraySort( candidates, 'text' );
						// return len( buffer ) - len( partialMatch );
						
						createCandidates( candidates, javaCandidates );
						return;

					}  // End are there params defined


				} // End what kind of params are we dealing with


			} // End was the command found


			arraySort( candidates, 'text' );
			// return len( buffer );
			
			createCandidates( candidates, javaCandidates );
			return;

		} catch ( any e ) {
			// by default, errors thrown from proxied components are useless and don't have an actual stack trace.
			shell.printError( e );
			return;
		}
	}

	/**
	 * populate completion candidates for parameter values
	 * @commandInfo.hint struct representing the command being completed for
	 * @paramName.hint param name
	 * @paramType.hint type of parameter (boolean, etc.)
	 * @paramSoFar.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function paramValueCompletion( struct commandInfo, String paramName, String paramType, String paramSoFar, required candidates, boolean namedParams ) {

		var completorData = commandInfo.commandReference.completor;

		if( structKeyExists( completorData, paramName ) ) {
			// Add static values
			if( structKeyExists( completorData[ paramName ], 'options' ) ) {
				addAllIfMatch( candidates, completorData[ paramName ][ 'options' ], paramSoFar, paramName, namedParams );
			}
			// Call function to populate dynamic values
			if( structKeyExists( completorData[ paramName ], 'optionsUDF' ) ) {
				var completorFunctionName = completorData[ paramName ][ 'optionsUDF' ];
				var additions = commandInfo.commandReference.CFC[ completorFunctionName ]( paramSoFar=arguments.paramSoFar );
				if( isArray( additions ) ) {
					addAllIfMatch( candidates, additions, paramSoFar, paramName, namedParams );
				}
			}
			// Completor annotations override default
			return;
		}

		switch(paramType) {
			case "Boolean" :
           		addCandidateIfMatch( "true", paramSoFar, candidates, paramName, namedParams );
           		addCandidateIfMatch( "false", paramSoFar, candidates, paramName, namedParams );
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
	 * Convience method since calling addAll() directly errors if each value isn't a string
	 * @candidates.hint Java TreeSet object
	 * @additions.hint array of values to add
 	 **/
	private function addAllIfMatch( candidates, array additions, paramSoFar, paramName, namedParams ) {
		for( var addition in additions ) {
       		addCandidateIfMatch( addition, arguments.paramSoFar, arguments.candidates, paramName, namedParams );
		}
	}

	/**
	 * Populate parameter value completion candidates
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
	 * @type.showFiles Whether to hit files as well as directories
 	 **/
	private function pathCompletion(String startsWith, required candidates, showFiles=true ) {
		// keep track of the original here so we can put it back like the user had
		var originalStartsWith = replace( arguments.startsWith, "\", "/", "all" );
		// Fully resolve the path.	
		arguments.startsWith = fileSystemUtil.resolvePath( arguments.startsWith );
		startsWith = replace( startsWith, "\", "/", "all" );

		// make sure dirs are suffixed with a trailing slash or we'll strip it off, thinking it's a partial name
		if( ( originalStartsWith == '' || originalStartsWith.endsWith( '/' ) ) && !startsWith.endsWith( '/' ) ) {
			startsWith &= '/';
		}

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

				// This comparison will be case-sensitive on Mac and Linux
				if( thisName.startsWith( partialMatch ) ) {
					// Do we care about this type?
					if( arguments.showFiles == true || path.type == 'dir' ) {

						// This is the absolute path that we matched
						var thisCandidate = searchIn & ( right( searchIn, 1 ) == '/' ? '' : '/' ) & path.name;
						
						// ...strip it back down to what they typed
						thisCandidate = replaceNoCase( thisCandidate, startsWith, originalStartsWith );
				
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
	private function addCandidateIfMatch( required match, required startsWith, required candidates, paramName, namedParams ) {
		startsWith = lcase( startsWith );
		if( lcase( match ).startsWith( startsWith ) || len( startsWith ) == 0 ) {
			if( !match.endsWith( '=' ) ) {
				match &= ' ';
			}
			if( namedParams ) {
				candidates.add( paramName & '=' & match );
			} else {
				candidates.add( match );	
			}
		}
	}


	/**
	* JLine3 needs an array of Java objects, so convert our array of strings to that
 	**/
	private function createCandidates( candidates, javaCandidates ) {
		
		candidates.each( function( candidate ){
				
			var thisCandidate = candidate.listLast( ' ' ) & ( candidate.endsWith( ' ' ) ? ' ' : '' );
			
			// systemOutput( 'adding: ' & thisCandidate, 1 );
			
			javaCandidates.append(
				createObject( 'java', 'org.jline.reader.Candidate' )
					.init(
						thisCandidate,				// value
						thisCandidate,				// displ
						javaCast( 'null', '' ),		// group      candidate.startsWith( '--' ) ? 'flags' : 'non-flags', 
						javaCast( 'null', '' ), 		// descr 
						javaCast( 'null', '' ), 		// suffix
						javaCast( 'null', '' ), 		// key
						false 						// complete
					)
			);			
		} );
		
	}

}
