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

}