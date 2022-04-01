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
	// env var/sys prop overrides
	property name="configSettingOverrides";
	// All known config settings-- really just for tab-completion right now
	property name="possibleConfigSettings";
	// The physical path there config settings are persisted
	property name="configFilePath";
	property name="serverServiceCompletePerformed" type="boolean" default="false";


	// DI
	property name='formatterUtil'		inject='formatter';
	property name='ModuleService'		inject='ModuleService';
	property name='JSONService'			inject='JSONService';
	property name='ServerService'		inject='provider:ServerService';

	/**
	* Constructor
	*/
	function init(){
		variables.system = createObject( 'java', 'java.lang.System' );

		// These aren't stored in the actual configSettings struct-- they're more for documentation
		// and smart auto-completion to help people set new settings.
		setPossibleConfigSettings([
			// Used in ModuleService
			'modulesExternalLocation',
			'modulesInclude',
			'modulesExclude',
			// HTTP Proxy settings
			'proxy.server',
			'proxy.port',
			'proxy.user',
			'proxy.password',
			// used in "run" command for a custom Unix shell
			'nativeShell',
			// used in "runTerminal" command for a custom app
			'nativeTerminal',
			// used to open an URL
			'preferredBrowser',
			// used in "bump" command
			'tagVersion',
			'tagPrefix',
			// Endpoint data
			'endpoints',
			'endpoints.defaultForgeBoxEndpoint',
			'endpoints.forgebox',
			'endpoints.forgebox.APIToken',
			'endpoints.forgebox.APIURL',
			// Servers
			'server',
			'server.singleServerMode',
			'server.defaults',
			'server.javaInstallDirectory',
			// used in Artifactsservice
			'artifactsDirectory',
			// commands
			'command',
			'command.defaults',
			'command.aliases',
			// Interactivity
			'nonInteractiveShell',
			'tabCompleteInline',
			'colorInDumbTerminal',
			'terminalWidth',
			// JSON
			'JSON.indent',
			'JSON.lineEnding',
			'JSON.spaceAfterColon',
			'JSON.sortKeys',
			'JSON.ANSIColors.constant',
			'JSON.ANSIColors.key',
			'JSON.ANSIColors.number',
			'JSON.ANSIColors.string',
			// General
			'verboseErrors',
			'debugNativeExecution',
			'developerMode',
			// Task Runners
			'taskCaching'
		]);

		setConfigFilePath( '/commandbox-home/CommandBox.json' );

		// Create the config file if necessary
		if( !fileExists( getConfigFilePath() ) ) {
			fileWrite( getConfigFilePath(), '{}' );
		}

		// Config settings that come from the JSON file
		loadConfig();

		return this;
	}

	function onDIComplete() {
		loadOverrides();
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
	* Get a setting from a configuration structure with JMESPath
	* @name.hint The name of the setting.  Allows for "deep" struct/array names.
	* @defaultValue.hint The default value to use if setting does not exist
	*/
	function getSettingJMES( required name, defaultValue ){
		arguments.JSON = getConfigSettings();
		arguments.property = arguments.name;

		return JSONService.showJMES( argumentCollection = arguments );
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

		arguments.JSON = getConfigSettings( noOverrides=true );
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

		arguments.JSON = getConfigSettings( noOverrides=true );
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
	* Return all config settings including env var/sys prop overrides
	*/
	function getConfigSettings( boolean noOverrides=false ) {
		if( noOverrides ) {
			return variables.configSettings;
		}

		// env var/system property overrides which we want to keep seperate so we don't write them back to the JSON file.
		return JSONService.mergeData( duplicate( variables.configSettings ), getConfigSettingOverrides() );
	}


	/**
	* Loads config settings from env vars or Java system properties
	*/
	function loadOverrides(){
		var overrides={};

		// Look for individual BOX settings to import.
		var processVarsUDF = function( envVar, value ) {
			// Loop over any that look like box_config_xxx
			if( envVar.len() > 11 && reFindNoCase('box[_\.]config[_\.]',  left( envVar, 11 ) ) ) {
				// proxy_host gets turned into proxy.host
				// Note, the asssumption is made that no config setting will ever have a legitimate underscore in the name
				var name = right( envVar, len( envVar ) - 11 ).replace( '_', '.', 'all' );
				JSONService.set( JSON=overrides, properties={ '#name#' : value }, thisAppend=true );
			}
		};

		// Get all OS env vars
		var envVars = system.getenv();
		for( var envVar in envVars ) {
			processVarsUDF( envVar, envVars[ envVar ] );
		}

		// Get all System Properties
		var props = system.getProperties();
		for( var prop in props ) {
			processVarsUDF( prop, props[ prop ] );
		}

		setConfigSettingOverrides( overrides );
	}

	/**
	* Persists config settings to disk
	*/
	function saveConfig(){
		JSONService.writeJSONFile( getConfigFilePath(), getConfigSettings( noOverrides=true ) );

		// Update ModuleService
		ModuleService.overrideAllConfigSettings();
	}


	/**
	* Dynamic completion for property name based on contents of commandbox.json
	* @all Pass false to ONLY suggest existing setting names.  True will suggest all possible settings.
	* @asSet Pass true to add = to the end of the options
	*/
	function completeProperty( all=false, asSet=false ) {
		if( !getServerServiceCompletePerformed() ) {
			var serverProps = serverService.completeProperty( 'fake', true );
			for( var prop in serverProps ) {
				variables.possibleConfigSettings.append( 'server.defaults.#prop#' );
			}
			setServerServiceCompletePerformed( true );
		}

		// Get all config settings currently set
		var props = JSONService.addProp( [], '', '', getConfigSettings() );

		// If we want all possible options...
		if( arguments.all ) {
			// ... Then add them in
			props.append( getPossibleConfigSettings(), true );
		}
		if( asSet ) {
			props = props.map( function( i ){ return i &= '='; } );
		}
		return props;
	}
}
