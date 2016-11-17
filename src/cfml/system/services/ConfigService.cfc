/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I handle working with the CommandBox.json file
*/
component accessors="true" singleton {

	// Holds the config settings in memory
	property name="configSettings";
	// All known config settings-- really just for tab-completion right now
	property name="possibleConfigSettings";
	// The physical path there config settings are persisted
	property name="configFilePath";

	// DI
	property name='formatterUtil'		inject='formatter';
	property name='ModuleService'		inject='ModuleService';
	property name='JSONService'			inject='JSONService';
	property name='ServerService'		inject='ServerService';
		
	/**
	* Constructor
	*/
	function init(){
		// These aren't stored in the actual configSettings struct-- they're more for documentation
		// and smart auto-completion to help people set new settings.
		setPossibleConfigSettings([
			// Used in ModuleService
			'ModulesExternalLocation',
			'modulesInclude',
			'ModulesExclude',
			// HTTP Proxy settings
			'proxy.server',
			'proxy.port',
			'proxy.user',
			'proxy.password',
			// used in "run" command for a custom Unix shell
			'nativeShell',
			// used in "bump" command
			'tagVersion',
			'tagPrefix',
			// Endpoint data
			'endpoints',
			'endpoints.forgebox',
			'endpoints.forgebox.APIToken',
			'endpoints.forgebox.APIURL',
			// Servers
			'server',
			'server.defaults'
		]);
		
		setConfigFilePath( '/commandbox-home/CommandBox.json' );
		
		// Create the config file if neccessary
		if( !fileExists( getConfigFilePath() ) ) {
			fileWrite( getConfigFilePath(), '{}' );
		}
		
		loadConfig();
		
		return this;
	}
	
	function onDIComplete() {
		var serverProps = serverService.completeProperty( 'fake', true );
		for( var prop in serverProps ) {
			variables.possibleConfigSettings.append( 'server.defaults.#prop#' );
		}
	}
	
	function setConfigSettings( required struct configSettings ) {
		variables.configSettings = arguments.configSettings;
		saveConfig();
	}
	
	/**
	* Get a setting from a configuration structure
	* @name.hint The name of the setting.  Allows for "deep" struct/array names.
	* @defaultValue.hint The default value to use if setting does not exist
	*/
	function getSetting( required name, defaultValue ){
		
		arguments.JSON = getConfigSettings();
		arguments.property = arguments.name;
		
		return JSONService.show( argumentCollection = arguments ); 
	}

	/**
	* Check if a value exists in a configuration structure
	* @name.hint The name of the setting.  Allows for "deep" struct/array names.
	*/
	boolean function settingExists( required name ){
		arguments.JSON = getConfigSettings();
		arguments.property = arguments.name;
		
		return JSONService.check( argumentCollection = arguments );
	}

	/**
	* Set a value in the application configuration settings
	* @name.hint The name of the setting.  Allows for "deep" struct/array names.
	* @value.hint The value to set
	* @thisAppend.hint Append an array or struct to existing
	*/
	function setSetting( required name, required value, boolean thisAppend=false ){
		
		arguments.JSON = getConfigSettings();
		arguments.properties[ name ] = arguments.value;
		
		JSONService.set( argumentCollection = arguments );
		
		saveConfig();
		return this;
	}

	/**
	* Remove a value in the application configuration settings
	* @name.hint The name of the setting.  Allows for "deep" struct/array names.
	*/
	function removeSetting( required name ){
		
		arguments.JSON = getConfigSettings();
		arguments.property = arguments.name;
		
		JSONService.clear( argumentCollection = arguments );
		
		saveConfig();
		return this;
	}

	/**
	* Loads config settings from disk
	*/
	function loadConfig(){
		// Don't call the setter here since we don't need to trigger a save.
		variables.configSettings = deserializeJSON( fileRead( getConfigFilePath() ) );				
	}

	/**
	* Persists config settings to disk
	*/
	function saveConfig(){
		fileWrite( getConfigFilePath(), formatterUtil.formatJSON( serializeJSON( getConfigSettings() ) ) );
				
		// Update ModuleService
		ModuleService.overrideAllConfigSettings();
	}

	
	/**
	* Dynamic completion for property name based on contents of commandbox.json
	* @all.hint Pass false to ONLY suggest existing setting names.  True will suggest all possible settings.
	*/ 	
	function completeProperty( all=false ) {
		// Get all config settings currently set
		var props = JSONService.addProp( [], '', '', getConfigSettings() );
		
		// If we want all possible options...
		if( arguments.all ) {
			// ... Then add them in
			props.append( getPossibleConfigSettings(), true );
		}
		
		return props;		
	}	
}