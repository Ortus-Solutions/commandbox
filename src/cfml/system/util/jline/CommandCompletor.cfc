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
		variables.functionList = getFunctionList();
		return this;
	}

	/**
	 * populate completion candidates and return cursor position
	 * @parsedLine.hint a dynamic proxy wrapping an instance of `ArgumentList.cfc`
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	numeric function complete( reader, parsedLine, candidates )  {

		try {

			var buffer = parsedLine.line();
			var bufferEndsWithSpace = buffer.endsWith( ' ' );

			// Try to resolve the command.
			// If buffer ends in space, we don't need to worry about the partial match of a command
			var commandChain = commandService.resolveCommand( line=buffer, forCompletion=!bufferEndsWithSpace );

			// If there are multiple commands like "help | more", we only care about the last one
			var commandInfo = commandChain[ commandChain.len() ];
			var isPiped = false;
			if( commandChain.len() > 2 && commandChain[ commandChain.len()-1 ].originalLine == '|' ) {
				isPiped = true;
			}
			
			// If we have a command chain, only worry about the last one
			if( commandChain.len() > 1 ) {
				buffer = commandInfo.originalLine & ( bufferEndsWithSpace ? ' ' : '' );
			}

			// Positive match up to this cursor position
			var matchedToHere = len( commandInfo.commandString );
			// Partial text that didn't match anything
			var leftOver = '';

			// TODO: Break REPL completion out into separate CFC
			// Tab completion for stuff like #now if we're still on the first word
			if( commandInfo.commandString.left( 4 ) == 'cfml' && commandInfo.originalLine.listLen( ' ' ) == 1 && !bufferEndsWithSpace ) {


				// Loop over all the possibilities at this level
				for( var func in variables.functionList ) {
					// Match the partial bit if it exists
					if( lcase( func ).startsWith( lcase( commandInfo.originalLine.right( -1 ) ) ) ) {
						// Add extra space so they don't have to
						add( candidates, '##' & func, 'CFML Functions', '', true );
					}
				}
				return;

			}

			// special handing for run command - suggest path completions for last token
			if ( commandInfo.commandstring == 'run' ) {
				pathCompletion( parsedLine.word(), candidates, true, '', false );
				return;
			}

			// If stuff was typed and it's an exact match to a command part
			if( matchedToHere == len( buffer ) && len( buffer ) ) {
				// Suggest a trailing space
				add( candidates, parsedLine.word(), '', '', true );

				return;
			// Everything else in the buffer is a partial, unmatched command
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
						var commandHint = '';
						if( commandInfo.commandReference[ command ].keyList() == '$' ) {
							commandHint = commandInfo.commandReference[ command ][ '$' ].hint.listFirst( '.#chr(13)##chr(10)#' ).trim();
						}
						add( candidates, command.listLast( ' ' ), ( commandInfo.commandReference[ command ].keyList() == '$' ? 'Commands' : 'Namespaces' ), commandHint, true );
					}
				}
				// Did we find ANYTHING?
				if( candidates.size() ) {
					return;
				} else {
					return;
				}


			// If we DID find a command and it's followed by a space, then suggest parameters
			} else {

				// This is all the possible params for the command
				var definedParameters = commandInfo.commandReference.parameters;
				// This is the params the user has entered so far.
				var passedParameters = commandService.parseParameters( commandInfo.parameters, definedParameters );
				var passedNamedParameters = passedParameters.namedParameters;

				if( arrayLen( passedParameters.positionalParameters ) ){
					passedNamedParameters = commandService.convertToNamedParameters( passedParameters.positionalParameters, definedParameters );
				}

				// For sure we are using named- suggest name or value as necessary
				if( structCount( passedParameters.namedParameters ) ) {

					var leftOver = '';

					// Still typing
					if( !bufferEndsWithSpace ) {

						// grab the last word from the parsed line
						var leftOver = parsedLine.word();

						// value completion only
						if( leftOver contains '=' ) {

							// Param name is bit before the =
							var paramName = listFirst( leftOver, '=' );
							// Everything else, is the value so far
							var paramSoFar = '';
							// There's only a value if something was typed after the =
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
							paramValueCompletion( commandInfo, paramName, paramType, paramSoFar, candidates, true, passedNamedParameters );

							return;
						}


					} // End still typing?

					// Loop over all possible params and suggest the ones not already there
					for( var param in definedParameters ) {
						if( !structKeyExists( passedParameters.namedParameters, param.name ) && !structKeyExists( passedParameters.flags, param.name ) ) {
							if( !len( leftOver ) || lcase( param.name ).startsWith( lcase( leftOver ) ) ) {
								add( candidates, param.name & '=', 'Parameters', param.hint ?: '' );
							}
							// If this is a boolean param, suggest the --flag version
							if( param.type == 'boolean' ) {
								var flagParamName = '--' & param.name;
								if( !len( leftOver ) || lcase( flagParamName ).startsWith( lcase( leftOver ) ) ) {
									add( candidates, flagParamName, 'Flags', param.hint ?: '', true );
								}
								var flagParamName = '--no' & param.name;
								if( !len( leftOver ) || lcase( flagParamName ).startsWith( lcase( leftOver ) ) ) {
									var negatedParamHint = !isNull( param.hint ) ? 'Not ' & param.hint.reReplace( '(^[A-Z])', '\L\1' ) : '';
									add( candidates, flagParamName, 'Flags', negatedParamHint, true );
								}
							}
						} // Does it exist yet?
					} // Loop over possible params

					return;

				// For sure positional - suggest next param name and value
				// Either there's more than one positional param supplied, or a single one with a space after it
				// or a single one with flags present
				} else if(
							passedParameters.positionalParameters.len() > 1
							|| ( passedParameters.positionalParameters.len() == 1
								&& ( bufferEndsWithSpace || structCount( passedParameters.flags ) ) )
						) {

					// If the buffer ends with a space, they were done typing the last param
					if( bufferEndsWithSpace ) {

						// Loop over remaining possible params and suggest the boolean ones as flags
						var i = 0;
						for( var param in definedParameters ) {
							i++;
							// If this is a boolean param not already here, suggest the --flag version
							if( i > passedParameters.positionalParameters.len() && param.type == 'boolean' && !structKeyExists( passedParameters.flags, param.name )  ) {
								add( candidates, '--' & param.name, 'Flags', param.hint ?: '', true );
								var negatedParamHint = !isNull( param.hint ) ? 'Not ' & param.hint.reReplace( '(^[A-Z])', '\L\1' ) : '';
								add( candidates, '--no' & param.name, 'Flags', negatedParamHint, true );
							}
						}
						var i = 0;
						for( var param in definedParameters ) {
							i++;
							// For every param we haven't reached that doesn't exist as a flag
							if( i > ( passedParameters.positionalParameters.len() + ( isPiped ? 1 : 0 ) ) && !structKeyExists( passedParameters.flags, param.name )) {
								// Add the name of the next one in the list. The user will have to backspace and
								// replace this with their actual param so this may not be that useful.

								add( candidates, param.name, 'Parameters', param.hint ?: '', true );
								paramValueCompletion( commandInfo, param.name, param.type, '', candidates, false, passedNamedParameters );
								// Bail once we find one
								break;
							}
						}

						return;

					// They were in the middle of typing
					} else {

						// Make sure defined params actually exist for this
						if( definedParameters.len() >= passedParameters.positionalParameters.len() ) {

							// If there is a passed positional param or flags
							if( passedParameters.positionalParameters.len() || structCount( passedParameters.flags ) ) {
								// grab the last chunk of text from the buffer
								var partialMatch = parsedLine.word();
							}

							var thisParam = definedParameters[ passedParameters.positionalParameters.len() ];
							paramValueCompletion( commandInfo, thisParam.name, thisParam.type, partialMatch, candidates, false, passedNamedParameters );

							// Loop over remaining possible params and suggest the boolean ones as flags
							var i = 0;
							for( var param in definedParameters ) {
								i++;
								// If this is a boolean param not already here, suggest the --flag version
								if( i >= passedParameters.positionalParameters.len() && param.type == 'boolean' && !structKeyExists( passedParameters.flags, param.name ) ) {
									var paramFlagname = '--' & param.name;
									if( lcase( paramFlagname ).startsWith( lcase( partialMatch ) ) ) {
										add( candidates, paramFlagname, 'Flags', param.hint ?: '', true );
									}
									var paramFlagname = '--no' & param.name;
									if( lcase( paramFlagname ).startsWith( lcase( partialMatch ) ) ) {
										var negatedParamHint = !isNull( param.hint ) ? 'Not ' & param.hint.reReplace( '(^[A-Z])', '\L\1' ) : '';
										add( candidates, paramFlagname, 'Flags', negatedParamHint, true );
									}
								}
							}

							return;
						}
					}

				// Too soon to tell - suggest first param name and first param value
				// There might be partially typed text, but there's no space at the end yet.
				} else {

					// Make sure defined params actually exist
					if( definedParameters.len() ) {

						var partialMatch = '';
						// If there is a passed positional param
						if( passedParameters.positionalParameters.len() ) {
							// grab the last one as the partial match
							partialMatch = passedParameters.positionalParameters.last();
						// If there are flags and the buffer doesn't end with a space, then we must still be typing one
						} else if( structCount( passedParameters.flags ) && !bufferEndsWithSpace ) {
							// grab the last chunk of text from the buffer
							partialMatch = parsedLine.word();
						}

						// Loop over all possible params and suggest them
						for( var param in definedParameters ) {
							// If this param is not already a flag and it matches the partial text add it
							if( !structKeyExists( passedParameters.flags, param.name )  && ( !len( partialMatch ) || lcase( param.name ).startsWith( lcase( partialMatch ) ) ) ) {
								add( candidates, param.name & '=', 'Parameters', param.hint ?: '' );
							}

							// If this param is a boolean that isn't a flag yet, suggest the --flag version
							var paramFlagname = '--' & param.name;
							if( param.type == 'boolean' && !structKeyExists( passedParameters.flags, param.name ) && lcase( paramFlagname ).startsWith( lcase( partialMatch ) ) ) {
								add( candidates, paramFlagname, 'Flags', param.hint ?: '', true );
							}

							// If this param is a boolean that isn't a flag yet, suggest the --flag version
							var paramFlagname = '--no' & param.name;
							if( param.type == 'boolean' && !structKeyExists( passedParameters.flags, param.name ) && lcase( paramFlagname ).startsWith( lcase( partialMatch ) ) ) {
								var negatedParamHint = !isNull( param.hint ) ? 'Not ' & param.hint.reReplace( '(^[A-Z])', '\L\1' ) : '';
								add( candidates, paramFlagname, 'Flags', negatedParamHint, true );
							}
						}

						// Grab first param
						var thisParam = definedParameters[ 1 ];
						if( isPiped && definedParameters.len() > 1 ) {
							thisParam = definedParameters[ 2 ];
						}

						// Suggest its value
						paramValueCompletion( commandInfo, thisParam.name, thisParam.type, partialMatch, candidates, false, passedNamedParameters );

						return;

					}  // End are there params defined


				} // End what kind of params are we dealing with


			} // End was the command found

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
	private function paramValueCompletion( struct commandInfo, String paramName, String paramType, String paramSoFar, required candidates, boolean namedParams, struct passedNamedParameters={} ) {
		
		var completorData = commandInfo.commandReference.completor;
		if( structKeyExists( completorData, paramName )
				&& ( structKeyExists( completorData[ paramName ], 'options' ) || structKeyExists( completorData[ paramName ], 'optionsUDF' ) )
			) {
			// Add static values
			if( structKeyExists( completorData[ paramName ], 'options' ) ) {
				addAllIfMatch( candidates, completorData[ paramName ][ 'options' ], paramSoFar, paramName, namedParams );
			}
			// Call function to populate dynamic values
			if( structKeyExists( completorData[ paramName ], 'optionsUDF' ) ) {
				var completorFunctionName = completorData[ paramName ][ 'optionsUDF' ];
				var additions = commandInfo.commandReference.CFC[ completorFunctionName ]( paramSoFar=arguments.paramSoFar, passedNamedParameters=passedNamedParameters );
				if( isArray( additions ) ) {
					addAllIfMatch( candidates, additions, paramSoFar, paramName, namedParams );
				}
			}

			// Should this param include directory or file completion (in addition to what came back from the options UDF?
			if( structKeyExists( completorData[ paramName ], 'optionsFileComplete' ) && completorData[ paramName ][ 'optionsFileComplete' ] ) {
				pathCompletion( paramSoFar, candidates, true, paramName, namedParams );
			}
			if( structKeyExists( completorData[ paramName ], 'optionsDirectoryComplete' ) && completorData[ paramName ][ 'optionsDirectoryComplete' ] ) {
				pathCompletion( paramSoFar, candidates, false, paramName, namedParams );
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
			paramName.endsWith( 'destination' ) ||
			// Has optionsDirectoryComplete annotation set to true
			( completorData[ paramName ][ 'optionsDirectoryComplete' ] ?: false )
		){
			pathCompletion( paramSoFar, candidates, false, paramName, namedParams );
		} else if( paramName.startsWith( 'file' ) ||
				   paramName.endsWith( 'file' ) ||
				   paramName.startsWith( 'path' ) ||
				   paramName.endsWith( 'path' ) ||
					// Has optionsFileComplete annotation set to true
				   ( completorData[ paramName ][ 'optionsFileComplete' ] ?: false )
		){
			pathCompletion( paramSoFar, candidates, true, paramName, namedParams );
		}
	}


	/**
	 * Convenience method since calling addAll() directly errors if each value isn't a string
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
	private function pathCompletion(String startsWith, required candidates, showFiles=true, paramName, namedParams ) {
		// keep track of the original here so we can put it back like the user had
		var originalStartsWith = arguments.startsWith;
		// Fully resolve the path.
		arguments.startsWith = fileSystemUtil.resolvePath( arguments.startsWith );
		startsWith = fileSystemUtil.normalizeSlashes( startsWith );

		// Even if the incoming string is a folder, keep off the trailing slash if the user hadn't typed it yet.
		if( originalStartsWith.len() && !listFind( '\,/', originalStartsWith.right( 1 ) ) && startsWith.endsWith( '/' ) ) {
			startsWith = startsWith.left( -1 );
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

						if( namedParams ) {
							add( candidates, paramName & '=' & thisCandidate & ( path.type == 'dir' ? '/' : '' ), ( path.type == 'dir' ? 'Directories' : 'Files' ), '', path.type != 'dir' );
						} else {
							add( candidates, thisCandidate & ( path.type == 'dir' ? '/' : '' ), ( path.type == 'dir' ? 'Directories' : 'Files' ), '', path.type != 'dir'  );
						}
					}
				}
			} // End path loop
		}
	}


	/**
	 * add a value completion candidate if it matches what was typed so far
	 * @match.hint text to compare as match or struct containing "name", "group", "description"
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function addCandidateIfMatch( required match, required startsWith, required candidates, paramName, namedParams ) {
		if( isStruct( match ) ) {
			var name = match.name;
			var group = match.group ?: 'Values';
			var description = match.description ?: '';
			var sort = match.sort ?: 999;
		} else {
			var name = match;
			var group = 'Values';
			var description = '';
			var sort = 999;
		}
		startsWith = lcase( startsWith );
		var complete = false;
		if( lcase( name ).startsWith( startsWith ) || len( startsWith ) == 0 ) {
			if( !toString( name ).endsWith( '=' ) ) {
				complete = true;
			}

			if( namedParams ) {
				add( candidates, paramName & '=' & name, group, description, complete, sort ?: nullValue() );
			} else {
				add( candidates, name, group, description, complete, sort );
			}
		}
	}

	/**
	* JLine3 needs an array of Java objects, so convert our array of strings to that
 	**/
	private function add( candidates, name, group='', description='', boolean complete = false, sort=999 ) {
		candidates.append(
			createObject( 'java', 'org.jline.reader.Candidate' )
				.init(
					name,											// value
					name,											// displ
					group,											// group
					description.len() ? description : nullValue(),	// descr
					nullValue(),									// suffix
					nullValue(),									// key
					complete//, 									// complete
					//val( sort )									// sort
				)
		);

	}

}
