/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* The DSL builder for all CommandBox-related stuff
*
*/
component implements="wirebox.system.ioc.dsl.IDSLBuilder" accessors=true{

	property name="injector";
	property name="log";

	/** 
	* Configure the DSL for operation and returns itself
	*/
    public any function init( required any injector ) output=false {
		setInjector( arguments.injector );
		setLog( arguments.injector.getLogBox().getLogger( this ) );
		return this;
	}

	
	/** 
	* Process an incoming DSL definition and produce an object with it.
	* @output false
	* @definition.hint The injection dsl definition structure to process. Keys: name, dsl
	* @targetObject.hint The target object we are building the DSL dependency for. If empty, means we are just requesting building
	*/
    public any function process( required definition, targetObject ) output=false {
    	
		var thisName 			= arguments.definition.name;
		var thisType 			= arguments.definition.dsl;
		var thisTypeLen 		= listLen(thisType,":");
		var thisLocationType 	= "";
		var thisLocationKey 	= "";
		var thisLocationToken	= "";

		// DSL stages
		switch(thisTypeLen){
			case 1: {
				return getInjector().getInstance( 'shell' );
			}
			// commandbox:{key} stage 2
			case 2: {
				thisLocationKey = getToken(thisType,2,":");
				switch( thisLocationKey ){
					case "moduleConfig"	: { return getInjector().getInstance( 'ModuleService' ).getModuleData(); }
					case "ConfigSettings"	: { return getInjector().getInstance( 'ConfigService' ).getConfigSettings(); }
				}

				break;
			}
			//commandbox:{key}:{target} 
			case 3: {
				thisLocationType = getToken(thisType,2,":");
				thisLocationKey  = getToken(thisType,3,":");
				switch(thisLocationType){
					case "moduleconfig"		: {
						var moduleConfig = getInjector().getInstance( 'ModuleService' ).getModuleData();
						// Check for module existance
						if( structKeyExists(moduleConfig, thisLocationKey ) ){
							return moduleConfig[ thisLocationKey ];
						} else if( getLog().canDebug() ){
							getLog().debug("The module requested: #thisLocationKey# does not exist in the loaded modules. Loaded modules are #structKeyList(moduleConfig)#");
						}
					}
					case "modulesettings"		: {
						var moduleConfig = getInjector().getInstance( 'ModuleService' ).getModuleData();
						// Check for module existance
						if( structKeyExists(moduleConfig, thisLocationKey ) ){
							return moduleConfig[ thisLocationKey ].settings;
						} else if( getLog().canDebug() ){
							getLog().debug("The module requested: #thisLocationKey# does not exist in the loaded modules. Loaded modules are #structKeyList(moduleConfig)#");
						}
					}
					case "ConfigSettings"		: {
						var configSettings = getInjector().getInstance( 'ConfigService' ).getConfigSettings();;
						// Check for setting existance
						if( structKeyExists(configSettings, thisLocationKey ) ){
							return configSettings[ thisLocationKey ];
						} else if( getLog().canDebug() ){
							getLog().debug("The config setting requested: #thisLocationKey# does not exist in the loaded settings. Loaded settings are #structKeyList(configSettings)#");
						}
					}
				}
				break;
			}
			//commandbox:{key}:{target}:{token}
			case 4: {
				thisLocationType = getToken(thisType,2,":");
				thisLocationKey  = getToken(thisType,3,":");
				thisLocationToken  = getToken(thisType,4,":");
				switch(thisLocationType){
					case "modulesettings"		: {
						var moduleConfig = getInjector().getInstance( 'ModuleService' ).getModuleData();
						// Check for module existance
						if( structKeyExists(moduleConfig, thisLocationKey ) ){
							// Check for setting existance
							if( structKeyExists( moduleConfig[ thisLocationKey ].settings, thisLocationToken ) ) {
								return moduleConfig[ thisLocationKey ].settings[ thisLocationToken ];
							} else if( getLog().canDebug() ){
								getLog().debug("The module requested: #thisLocationKey# does not exist in the loaded modules. Loaded modules are #structKeyList(moduleConfig)#");
							}							
						} else if( getLog().canDebug() ){
							getLog().debug("The module requested: #thisLocationKey# does not exist in the loaded modules. Loaded modules are #structKeyList(moduleConfig)#");
						}
					}
				}
				break;
			}
		}
		
		// debug info
		if( getLog().canDebug() ){
			getLog().debug("getColdboxDSL() cannot find dependency using definition: #arguments.definition.toString()#");
		}    
	}



}