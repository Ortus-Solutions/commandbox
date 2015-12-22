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
	
	/**
	* Constructor
	*/
	function init(){
		// These aren't stored in the actual configSettings struct-- they're more for documentation
		// and smart auto-completion to help people set new settings.
		setPossibleConfigSettings([
			'ModulesExternalLocation',
			'modulesInclude',
			'ModulesExclude',
			'showBanner'			
		]);
		
		setConfigFilePath( '/commandbox-home/CommandBox.json' );
		
		// Create the config file if neccessary
		if( !fileExists( getConfigFilePath() ) ) {
			fileWrite( getConfigFilePath(), '{}' );
		}
		
		loadConfig();
		
		return this;
	}
	
	function setConfigSettings( required struct configSettings ) {
		variables.configSettings = arguments.configSettings;
		saveConfig();
	}
	
	/**
	* Get a setting from a configuration structure
	* @name The name of the setting
	* @fwSetting Switch to get the coldbox or config settings, defaults to config settings
	* @defaultValue The default value to use if setting does not exist
	*/
	function getSetting( required name, defaultValue ){

		if ( settingExists( arguments.name ) ){
			return getConfigSettings()[ arguments.name ];
		}

		// Default value
		if( structKeyExists( arguments, "defaultValue" ) ){
			return arguments.defaultValue;
		}

		throw( message="The setting #arguments.name# does not exist.",
			   detail="",
			   type="ConfigService.SettingNotFoundException");
	}

	/**
	* Check if a value exists in a configuration structure
	* @name The name of the setting
	* @fwSetting Switch to get the coldbox or config settings, defaults to config settings
	*/
	boolean function settingExists( required name ){
		return ( structKeyExists( getConfigSettings(), arguments.name ) );
	}

	/**
	* Set a value in the application configuration settings
	* @name The name of the setting
	* @value The value to set
	* 
	* @return ConfigService
	*/
	function setSetting( required name, required value ){
		getConfigSettings()[ arguments.name ] = arguments.value;
		
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
				
		// Update ModuleService
		ModuleService.overrideAllConfigSettings();		
				
		fileWrite( getConfigFilePath(), formatterUtil.formatJSON( serializeJSON( getConfigSettings() ) ) );
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