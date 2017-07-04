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

	variables.system = createObject( "java", "java.lang.System" );

	/**
	* Retrieve a Java System property or env value by name.
	*
	* @key The name of the setting to look up.
	* @defaultValue The default value to use if the key does not exist in the system properties
	*/
    function getSystemSetting( required string key, defaultValue ) {

		var value = system.getProperty( arguments.key );
		if ( ! isNull( value ) ) {
			return value;
		}

		value = system.getEnv( arguments.key );
		if ( ! isNull( value ) ) {
			return value;
		}

		if ( ! isNull( arguments.defaultValue ) ) {
			return arguments.defaultValue;
		}

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
	function expandSystemSettings( required string text ) {
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
			var result = getSystemSetting( settingName, defaultValue );

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
	function expandDeepSystemSettings( required any dataStructure ) {
		// If it's a struct...
		if( isStruct( dataStructure ) ) {
			// Loop over and process each key
			for( var key in dataStructure ) {
				dataStructure[ key ] = expandDeepSystemSettings( dataStructure[ key ] );
			}
			return dataStructure;
		// If it's an array...
		} else if( isArray( dataStructure ) ) {
			var i = 0;
			// Loop over and process each index
			for( var item in dataStructure ) {
				i++;
				dataStructure[ i ] = expandDeepSystemSettings( item );
			}
			return dataStructure;
		// If it's a string...
		} else if ( isSimpleValue( dataStructure ) ) {
			// Just do the replacement
			return expandSystemSettings( dataStructure );
		}
		// Other complex variables like XML or CFC instance would just get skipped for now.
		return dataStructure;
	}

}