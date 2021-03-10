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
					case "interceptorService"	: { return getInjector().getInstance( 'interceptorService' ); }
					case "moduleService"	: { return getInjector().getInstance( 'moduleService' ); }
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
						// Check for module existence
						if( structKeyExists(moduleConfig, thisLocationKey ) ){
							return moduleConfig[ thisLocationKey ];
						} else {
							throw( message="CommandBox DSL cannot find dependency using definition: #arguments.definition.toString()#", detail="The module requested: #thisLocationKey# does not exist in the loaded modules. Loaded modules are #structKeyList(moduleConfig)#" );
						}
					}
					case "interceptor"		: {
						return getInjector().getInstance( 'interceptorService' ).getInterceptor( thisLocationKey );
					}
					case "modulesettings"		: {
						var moduleConfig = getInjector().getInstance( 'ModuleService' ).getModuleData();
						// Check for module existence
						if( structKeyExists(moduleConfig, thisLocationKey ) ){
							return moduleConfig[ thisLocationKey ].settings;
						} else {
							throw( message="CommandBox DSL cannot find dependency using definition: #arguments.definition.toString()#", detail="The module requested: #thisLocationKey# does not exist in the loaded modules. Loaded modules are #structKeyList(moduleConfig)#" );
						}
					}
					case "setting" : case "ConfigSettings"	: {

						// Getting setting from module
						if( thisLocationKey contains '@' ) {

							thisLocationToken  = listFirst( thisLocationKey, '@' );
							thisLocationKey  = listRest( thisLocationKey, '@' );

							return getModuleSetting( definition,  thisLocationKey, thisLocationToken );

						} else {

							var configService = getInjector().getInstance( 'ConfigService' );
							var configSettings = configService.getConfigSettings();

							// Check for setting existence
							if( configService.settingExists( thisLocationKey ) ){
								return configService.getSetting( thisLocationKey );
							} else {
								throw( message="CommandBox DSL cannot find dependency using definition: #arguments.definition.toString()#", detail="The config setting requested: #thisLocationKey# does not exist in the loaded settings. Loaded settings are #structKeyList(configSettings)#" );
							}
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
						return getModuleSetting( definition,  thisLocationKey, thisLocationToken );
					}
				}
				break;
			}
		}

		throw( message="CommandBox DSL cannot find dependency using definition: #arguments.definition.toString()#", detail="Unknown DSL" );

	}

	function getModuleSetting( definition, thisLocationKey, thisLocationToken ) {

		var moduleConfig = getInjector().getInstance( 'ModuleService' ).getModuleData();
		// Check for module existence
		if( structKeyExists(moduleConfig, thisLocationKey ) ){
			// Check for setting existence
			if( structKeyExists( moduleConfig[ thisLocationKey ].settings, thisLocationToken ) ) {
				return moduleConfig[ thisLocationKey ].settings[ thisLocationToken ];
			} else {
				throw( message="CommandBox DSL cannot find dependency using definition: #arguments.definition.toString()#", detail="The setting requested: #thisLocationToken# does not exist in this module. Loaded settings are #structKeyList(moduleConfig[ thisLocationKey ].settings)#" );
			}
		} else {
			throw( message="CommandBox DSL cannot find dependency using definition: #arguments.definition.toString()#", detail="The module requested: #thisLocationKey# does not exist in the loaded modules. Loaded modules are #structKeyList(moduleConfig)#" );
		}

	}


}
