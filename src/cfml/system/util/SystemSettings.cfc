/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handled accessing environment variables and system properties
*
*/
component singleton {
	property name='commandService'		inject='CommandService';
	property name='interceptorService'	inject='interceptorService';

	variables.system = createObject( "java", "java.lang.System" );
	// Default environment for the shell
	variables.environment = {};
	
	/**
	* Retrieve a Java System property or env value by name.
	*
	* @key The name of the setting to look up.
	* @defaultValue The default value to use if the key does not exist in the system properties
	*/
    function getSystemSetting( required string key, defaultValue, any context={} ) {

		// Allow for custom setting resolution
		var interceptData = {
			setting : key,
			defaultValue : defaultValue ?: '',
			resolved : false,
			context : context
		};
		interceptorService.announceInterception( 'onSystemSettingExpansion', interceptData );
		if( interceptData.resolved ) {
			return interceptData.setting;
		}

		// See if the key exists in the current env or any of the parent envs
		var cs = commandService.getCallStack();
		for( var call in cs ) {
			if ( call.environment.keyExists( key ) ) {
				return call.environment[ key ];
			}
		}
		
		// See if the default shell env has it
		if ( variables.environment.keyExists( key ) ) {
			return variables.environment[ key ];
		}

		// Now check Java system props
		var value = system.getProperty( arguments.key );
		if ( ! isNull( value ) ) {
			return value;
		}

		// Finally check OS env vars.
		value = system.getEnv( arguments.key );
		if ( ! isNull( value ) ) {
			return value;
		}

		// Umm, is there a default?
		if ( ! isNull( arguments.defaultValue ) ) {
			return arguments.defaultValue;
		}

		// Yeah, I give up.
		throw(
			type = "SystemSettingNotFound",
			message = "Could not find a Java System property or Env setting with key [#arguments.key#]."
		);
	}

	/**
	* Retrieve a Java System property by name.
	*
	* @key The name of the setting to look up.
	* @defaultValue The default value to use if the key does not exist in the system properties
	*/
    function getSystemProperty( required string key, defaultValue ) {

		var value = system.getProperty( arguments.key );
		if ( ! isNull( value ) ) {
			return value;
		}

		if ( ! isNull( arguments.defaultValue ) ) {
			return arguments.defaultValue;
		}

		throw(
			type = "SystemSettingNotFound",
			message = "Could not find a Java System property with key [#arguments.key#]."
		);
	}

	/**
	* Set a System Setting into the current environment
	*
	* @key The name of the setting to set.
	* @value The value to use
	* @inParent Pass true to set the variable in the parent environment
	*/
    function setSystemSetting( required string key, required string value, inParent=false ) {
    	var env = getCurrentEnvironment( inParent );
		env[ arguments.key ] = arguments.value;
	}

	/**
	* Set a Java System property.
	*
	* @key The name of the setting to set.
	* @value The value to use
	*/
    function setSystemProperty( required string key, required string value ) {
		system.setProperty( arguments.key, arguments.value );
	}

	/**
	* Retrieve an env value by name.
	*
	* @key The name of the setting to look up.
	* @defaultValue The default value to use if the key does not exist in the env
	*/
    function getEnv( required string key, defaultValue ) {

		var value = system.getEnv( arguments.key );
		if ( ! isNull( value ) ) {
			return value;
		}

		if ( ! isNull( arguments.defaultValue ) ) {
			return arguments.defaultValue;
		}

		throw(
			type = "SystemSettingNotFound",
			message = "Could not find a env property with key [#arguments.key#]."
		);

	}


	/**
	* Expands placeholders like ${foo} in a string with the matching java prop or env var.
	* Will replace as many place holders that exist, but will skip escaped ones like \${do.not.expand.me}
	*
	* @text The string to do the replacement on
	*/
	function expandSystemSettings( required string text, any context={} ) {
		// Temporarily remove escaped ones like \${do.not.expand.me}
		text = replaceNoCase( text, '\${', '__system_setting__', "all" );
		// Mark all system settings
		text = reReplaceNoCase( text, '\$\{(.*?)}', '__system__\1__system__', 'all' );
		// put escaped stuff back
		text = replaceNoCase( text, '__system_setting__', '${', "all" );

		// Look for a system setting "foo" flagged as "__system__foo__system__"
		var search = reFindNoCase( '__system__.*?__system__', text, 1, true );

		// As long as there are more system settings
		while( search.pos[1] ) {
			// Extract them
			var systemSetting = mid( text, search.pos[1], search.len[1] );
			// Evaluate them
			var settingName = mid( systemSetting, 11, len( systemSetting )-20 );
			var defaultValue = '';
			if( settingName.listLen( ':' ) ) {
				defaultValue = settingName.listRest( ':' );
				settingName = settingName.listFirst( ':' );
			}
						
			var result = getSystemSetting( settingName, defaultValue, context );

			// And stick their results in their place
			text = replaceNoCase( text, systemSetting, result, 'one' );
			// Search again
			var search = reFindNoCase( '__system__.*?__system__', text, 1, true );
		}
		return text;
	}

	/**
	* Expands placeholders like ${foo} in all deep struct keys and array elements with the matching java prop or env var.
	* Will replace as many place holders that exist, but will skip escaped ones like \${do.not.expand.me}
	* This will recursivley follow all nested structs and arrays.
	*
	* @dataStructure A string, struct, or array to perform deep replacement on.
	*/
	function expandDeepSystemSettings( required any dataStructure, any context=dataStructure ) {
		// If it's a struct...
		if( isStruct( dataStructure ) ) {
			// Loop over and process each key
			for( var key in dataStructure ) {
				var expandedKey = expandSystemSettings( key, context );
				dataStructure[ expandedKey ] = expandDeepSystemSettings( dataStructure[ key ], context );
				if( expandedKey != key ) dataStructure.delete( key );
			}
			return dataStructure;
		// If it's an array...
		} else if( isArray( dataStructure ) ) {
			var i = 0;
			// Loop over and process each index
			for( var item in dataStructure ) {
				i++;
				dataStructure[ i ] = expandDeepSystemSettings( item, context );
			}
			return dataStructure;
		// If it's a string...
		} else if ( isSimpleValue( dataStructure ) ) {
			// Just do the replacement
			return expandSystemSettings( dataStructure, context );
		}
		// Other complex variables like XML or CFC instance would just get skipped for now.
		return dataStructure;
	}
	

	/**
	* Take a struct of data and set system settings for each deep key
	*
	* @dataStructure A string, struct, or array. Initial value should be a struct.
	*/
	function setDeepSystemSettings( any dataStructure, string prefix='interceptData' ) {
		
		// If it's a struct...
		if( isStruct( dataStructure ) && !isObject( dataStructure ) ) {
			// Loop over and process each key
			for( var key in dataStructure ) {
				if( key != 'COMMANDREFERENCE' ) {
					setDeepSystemSettings( dataStructure[ key ] ?: '', prefix.listAppend( key, '.' ) );
				}
			}
		// If it's an array...
		} else if( isArray( dataStructure ) ) {
			var i = 0;
			// Loop over and process each index
			for( var item in dataStructure ) {
				i++;
				setDeepSystemSettings( item ?: '', prefix & '[#i#]' );
			}
		// If it's a string...
		} else if ( isSimpleValue( dataStructure ) ) {
			// Just set the setting
			setSystemSetting( prefix, toString( dataStructure ?: '' ) );
		}
		
	}

	/**
	* Return current environment for the shell.
	*
	* @parent Get the parent environment
	*/	
	struct function getCurrentEnvironment( parent=false ) {
		// If there is an executing command, use the env for that command
		var cs = commandService.getCallStack();
		
		// Check for a parent command
		if( parent ) {
			if( cs.len() > 1 ) {
				return cs[ 2 ].environment;
			}
		// Fall back to current command if not getting parent
		} else {
			if( cs.len() ) {
				return cs[ 1 ].environment;
			}			
		}
		
		// Otherwise, the default shell env
		// We'll also hit this if getting the parent, but there is only one command level deep processing.
		return variables.environment;
	}


	/**
	* Return an array of environment context with the current one at the top
	*/	
	array function getAllEnvironments() {
		var envs = [];
		var cs = commandService.getCallStack();
		
		for( var call in cs ) {
			envs.append( {
				'context' : call.commandInfo.originalLine,
				'environment' : call.environment
			} );
		}
		
		envs.append( {
			'context' : 'Global Shell',
			'environment' : variables.environment
		} );
		
		return envs;
	}


	/**
	* Return a representation of the environment context including all parent contexts
	* but not including Java system props and OS env vars flattended into a single struct.
	*/	
	struct function getAllEnvironmentsFlattened() {
		var envFlat = {};
		getAllEnvironments().each( function( env ) {
			envFlat.append( env.environment, false );
		} );
		
		return envFlat;
	}
	
}
