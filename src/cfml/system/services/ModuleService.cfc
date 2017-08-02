<!-----------------------------------------------------------------------
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
* This service oversees all CommandBox Modules
----------------------------------------------------------------------->
<cfcomponent output="false" accessors=true singleton>

	<!---
	Unlike ColdBox which stores all module config and settings in the framework setting struct,
	CommandBox's ModuleService will internalize this data.  CommandBox "config" settings will
	just mirror the CommandBox.json file and not include runtime metadata like this.  Any time
	a config setting is updated programmatically for a module, CommandBox's ConfigService
	will attempt to keep this runtime data in sync.  Module's will ask the ModuleService for their
	data which will come from here, overriden at load time by any config settings if they exist.
	--->
	<cfproperty name="moduleData">

	<!--- DI --->
	<cfproperty name="CommandService" inject="CommandService">
	<cfproperty name="EndpointService" inject="EndpointService">
	<cfproperty name="ConfigService" inject="Configservice">
	<cfproperty name="SystemSettings" inject="SystemSettings">
	<cfproperty name="consoleLogger" inject="logbox:logger:console">


<!------------------------------------------- CONSTRUCTOR ------------------------------------------->

	<cffunction name="init" access="public" output="false" returntype="ModuleService" hint="Constructor">
		<cfargument name="shell" inject="shell" type="any" required="true">
		<cfscript>
			variables.shell = arguments.shell;

			// service properties
			instance.logger 			= "";
			instance.mConfigCache 		= {};
			instance.moduleRegistry 	= createObject( "java", "java.util.LinkedHashMap" ).init();
			instance.cfmappingRegistry 	= {};

			setModuleData( {} );

			return this;
		</cfscript>
	</cffunction>

<!------------------------------------------- INTERNAL COMMANDBOX EVENTS ------------------------------------------->


    <cffunction name="getShell" output="false">
    	<cfreturn shell>
    </cffunction>

	<!--- onConfigurationLoad --->
    <cffunction name="configure" output="false" access="public" returntype="void" hint="Called by loader service when configuration file loads">
    	<cfscript>
			//Get Local Logger Now Configured
			instance.logger = shell.getLogBox().getLogger(this);

    		// Register The Modules
			registerAllModules();
    	</cfscript>
    </cffunction>

	<!--- onShutdown --->
    <cffunction name="onShutdown" output="false" access="public" returntype="void" hint="Called when the application stops">
    	<cfscript>
    		// Unload all modules
			unloadAll();
    	</cfscript>
    </cffunction>

<!------------------------------------------- PUBLIC ------------------------------------------->

	<!--- getModuleRegistry --->
    <cffunction name="getModuleRegistry" output="false" access="public" returntype="struct" hint="Get the discovered module's registry structure">
    	<cfreturn instance.moduleRegistry>
    </cffunction>

    <!--- getModuleConfigCache  --->
    <cffunction name="getModuleConfigCache" access="public" returntype="struct" output="false" hint="Return the loaded module's configuration objects">
    	<cfreturn instance.mConfigCache>
    </cffunction>

	<!--- rebuildRegistry --->
    <cffunction name="rebuildModuleRegistry" output="false" access="public" returntype="any" hint="Rescan the module locations directories and re-register all located modules, this method does NOT register or activate any modules, it just reloads the found registry">
    	<cfscript>
    		// Add the application's module's location and the system core modules
    		var modLocations   = [ '/commandbox/system/modules','/commandbox/system/modules_app', '/commandbox/modules' ];
			// Add the application's external locations array.
			modLocations.addAll( ConfigService.getSetting( "ModulesExternalLocation", [] ) );
			// iterate through locations and build the module registry in order
			buildRegistry( modLocations );
		</cfscript>
    </cffunction>

	<!--- registerAllModules --->
	<cffunction name="registerAllModules" output="false" access="public" returntype="ModuleService" hint="Register all modules for the application. Usually called by framework to load configuration data.">
		<cfscript>
			var foundModules   = "";
			var includeModules = ConfigService.getSetting( "modulesInclude", [] );

			// Register the initial empty module configuration holder structure
			structClear( getModuleData() );
			// clean the registry as we are registering all modules
			instance.moduleRegistry = createObject( "java", "java.util.LinkedHashMap" ).init();
			// Now rebuild it
			rebuildModuleRegistry();

			// Are we using an include list?
			if( arrayLen( includeModules ) ){
				for( var thisModule in includeModules ){
					// does module exists in the registry? We only register what is found
					if( structKeyExists( instance.moduleRegistry, thisModule ) ){
						registerModule( thisModule );
					}
				}
				return this;
			}

			// Iterate through registry and register each module
			var aModules = structKeyArray( instance.moduleRegistry );
			for( var thisModule in aModules ){
				if( canLoad( thisModule ) ){
					registerModule( thisModule );
				}
			}

			return this;
		</cfscript>
	</cffunction>

	<!--- registerAndActivateModule --->
    <cffunction name="registerAndActivateModule" output="false" access="public" returntype="void" hint="Register and activate a new module">
    	<cfargument name="moduleName" 		type="string" required="true" hint="The name of the module to load."/>
		<cfargument name="invocationPath" 	type="string" required="false" default="" hint="The module's invocation path to its root from the webroot (the instantiation path,ex:myapp.myCustomModules), if empty we use registry location, if not we are doing a explicit name+path registration. Do not include the module name, you passed that in the first argument right"/>
		<cfscript>
			registerModule( arguments.moduleName, arguments.invocationPath );
			activateModule( arguments.moduleName );
		</cfscript>
    </cffunction>

	<!--- registerModule --->
	<cffunction name="registerModule" output="false" access="public" returntype="boolean" hint="Register a module's configuration information and config object">
		<cfargument name="moduleName" 		type="string" 	required="true" hint="The name of the module to load."/>
		<cfargument name="invocationPath" 	type="string" 	required="false" default="" hint="The module's invocation path to its root from the webroot (the instantiation path,ex:myapp.myCustomModules), if empty we use registry location, if not we are doing a explicit name+path registration. Do not include the module name, you passed that in the first argument right"/>
		<cfargument name="parent"			type="string" 	required="false" default="" hint="The name of the parent module">
		<cfargument name="force" 			type="boolean" 	required="false" default="false" hint="Force a registration"/>
		<cfscript>
			// Module To Load
			var modName 				= arguments.moduleName;
			var modulesConfiguration	= getModuleData();
			// CommandBox doesn't really have settings per se--
			// at least not ones I'm comfortable with modules overriding.
			//var appSettings 			= shell.getConfigSettings();


			// Check if incoming invocation path is sent, if so, register as new module
			if( len( arguments.invocationPath ) ){
				// Check if passed module name is already registered
				if( structKeyExists( instance.moduleRegistry, arguments.moduleName ) AND !arguments.force ){
					instance.logger.warn( "The module #arguments.moduleName# has already been registered, so skipping registration" );
					return false;
				}
				// register new incoming location
				instance.moduleRegistry[ arguments.moduleName ] = {
					locationPath 	= "/" & replace( arguments.invocationPath,".","/","all" ),
					physicalPath 	= expandPath( "/" & replace( arguments.invocationPath,".","/","all" ) ),
					invocationPath 	= arguments.invocationPath
				};
			}

			// Check if passed module name is not loaded into the registry
			if( NOT structKeyExists( instance.moduleRegistry, arguments.moduleName ) ){
				throw( message="The module #arguments.moduleName# is not valid",
					   detail="Valid module names are: #structKeyList( instance.moduleRegistry )#",
					   type="ModuleService.InvalidModuleName" );
			}

			// Setup module metadata info
			var modulesLocation 		= instance.moduleRegistry[ modName ].locationPath;
			var modulesPath 			= instance.moduleRegistry[ modName ].physicalPath;
			var modulesInvocationPath	= instance.moduleRegistry[ modName ].invocationPath;
			var modLocation				= modulesPath & "/" & modName;
			var isBundle				= listLast( modLocation, "-" ) eq "bundle";

			// Check if module config exists, or we have a module.
			if( NOT fileExists( modLocation & "/ModuleConfig.cfc" ) && NOT isBundle ){
				instance.logger.WARN( "The module (#modName#) cannot be loaded as it does not have a ModuleConfig.cfc in its root. Path Checked: #modLocation#" );
				return false;
			}

			// Module Bundle Registration
			if( isBundle ){
				// Bundle Loading
				var aBundleModules = directoryList( modLocation, false, "array" );
				for( var thisModule in aBundleModules ){
					// cleanup module name
					var bundleModuleName = listLast( thisModule, "/\" );
					// register the bundle module
					registerModule( moduleName=bundleModuleName,
									invocationPath=modulesInvocationPath & "." & modName,
									parent=modName,
									force=true );
				}
				// the bundle has loaded, it needs no config data
				return true;
			}

			// lock registration
			lock name="module.registration.#arguments.modulename#" type="exclusive" throwontimeout="true" timeout="20"{

				// Setup Vanilla Config information for module
				var mConfig = {
					// Module MetaData and Directives
					title				= "",
					// execution aliases
					aliases				= [],
					author				="",
					webURL				="",
					description			="",
					version				="",
					// ColdFusion mapping
					cfmapping			= modName,
					// Models namespsace
					modelNamespace		= modName,
					// Auto map models flag
					autoMapModels		= true,
					// when this registration ocurred
					loadTime 			= now(),
					// Flag that denotes if the module has been activated or not
					activated 			= false,
					// Any dependencies this module requires to be loaded first
					dependencies		= [],
					// Flag that says if this module should NOT be loaded
					disabled			= false,
					// flag that says if this module can be activated or not
					activate			= true,
					// Module Configurations
					path				 	= modLocation,
					invocationPath 			= modulesInvocationPath & "." & modName,
					mapping 				= modulesLocation & "/" & modName,
					modelsInvocationPath    = modulesInvocationPath & "." & modName,
					modelsPhysicalPath		= modLocation,
					commandsInvocationPath  = modulesInvocationPath & "." & modName,
					commandsPhysicalPath	= modLocation,
					endpointsInvocationPath = modulesInvocationPath & "." & modName,
					endpointsPhysicalPath   = modLocation,
					parentSettings			= {},
					settings 				= {},
					interceptors 			= [],
					interceptorSettings     = { customInterceptionPoints = "" },
					conventions = {
						modelsLocation      = "models",
						commandsLocation    = "commands",
						endpointsLocation   = "endpoints"
					},
					childModules			= [],
					parent 					= arguments.parent
				};


				try {
					// Load Module configuration from cfc and store it in module Config Cache
					var oConfig = loadModuleConfiguration( mConfig, arguments.moduleName );
				} catch( any var e ) {
					consoleLogger.error( 'There was an error loading module [#arguments.moduleName#]' );
					consoleLogger.error( '#e.message##chr( 10 )##e.detail#' );
					instance.logger.error( 'There was an error loading module [#arguments.moduleName#]', e );
					return false;
				}
				// Verify if module has been disabled
				if( mConfig.disabled ){
					if( instance.logger.canDebug() ){
						instance.logger.debug( "Skipping module: #arguments.moduleName# as it has been disabled!" );
					}
					return false;
				} else {
					instance.mConfigCache[ modName ] = oConfig;
				}
				// Store module configuration in main modules configuration
				modulesConfiguration[ modName ] = mConfig;
				// Link aliases by reference in both modules list and config cache
				for( var thisAlias in mConfig.aliases ){
					modulesConfiguration[ thisAlias ] 	= modulesConfiguration[ modName ];
					instance.mConfigCache[ thisAlias ]  = instance.mConfigCache[ modName ];
				}
				// Update the paths according to conventions
				mConfig.modelsInvocationPath    &= ".#replace( mConfig.conventions.modelsLocation, "/", ".", "all" )#";
				mConfig.modelsPhysicalPath		&= "/#mConfig.conventions.modelsLocation#";

				mConfig.commandsInvocationPath  &= ".#replace( mConfig.conventions.commandsLocation, "/", ".", "all" )#";
				mConfig.commandsPhysicalPath	&= "/#mConfig.conventions.commandsLocation#";

				mConfig.endpointsInvocationPath &= ".#replace( mConfig.conventions.endpointsLocation, "/", ".", "all" )#";
				mConfig.endpointsPhysicalPath	&= "/#mConfig.conventions.endpointsLocation#";

				// Register CFML Mapping if it exists, for loading purposes
				if( len( trim( mConfig.cfMapping ) ) ){
					shell.getUtil().addMapping( name=mConfig.cfMapping, path=mConfig.path );
					instance.cfmappingRegistry[ mConfig.cfMapping ] = mConfig.path;
				}
				// Register Custom Interception Points
				shell.getInterceptorService().appendInterceptionPoints( mConfig.interceptorSettings.customInterceptionPoints );
				// Register Parent Settings
				//structAppend( appSettings, mConfig.parentSettings, true );
				// Inception?
				if( directoryExists( mConfig.path & "/modules" ) ){
					// register the children
					var childModules = directoryList( mConfig.path & "/modules", false, "array" );
					for( var thisChild in childModules ){
						// cleanup module name
						var childName = listLast( thisChild, "/\" );
						// verify ModuleConfig exists, else skip
						if( fileExists( thisChild & "/ModuleConfig.cfc" ) ){
							// add to parent children
							arrayAppend( mConfig.childModules, childname );
							// register it
							registerModule( moduleName=childName,
											invocationPath=mConfig.invocationPath & ".modules",
											parent=modName );
						} else if( instance.logger.canDebug() ){
							instance.logger.debug( "Inception Module #childName# does not have a valid ModuleConfig.cfc in its root, so skipping registration" );
						}
					}
				}

				// Log registration
				if( instance.logger.canDebug() ){
					instance.logger.debug( "Module #arguments.moduleName# registered successfully." );
				}
			} // end lock

			return true;
		</cfscript>
	</cffunction>

	<!--- loadMappings --->
    <cffunction name="loadMappings" output="false" access="public" returntype="any" hint="Load all module mappings">
    	<cfscript>
			// Iterate through cfmapping registry and load them
			for( var thisMapping in instance.cfmappingRegistry ){
				shell.getUtil().addMapping( name=thisMapping, path=instance.cfmappingRegistry[ thisMapping ] );
			}
    	</cfscript>
    </cffunction>

	<!--- activateModules --->
	<cffunction name="activateAllModules" output="false" access="public" returntype="void" hint="Go over all the loaded module configurations and activate them for usage within the application">
		<cfscript>
			var modules = getModuleData();
			// Iterate through module configuration and activate each module
			for( var moduleName in modules ){
				// Verify the exception and inclusion lists
				if( canLoad( moduleName ) ){
					try {
						activateModule( moduleName );
					} catch( any var e ) {
						systemOutput( 'Module [#moduleName#] failed to load!  Check the logs for more info.', true );
						systemOutput( '    ' & e.message, true );
						if( (e.detail ?: '').len() ) {
							systemOutput( '    ' & e.detail, true );
						}
						systemOutput( '    ' & e.tagContext[ 1 ].template & ':' &  e.tagContext[ 1 ].line, true );
						systemOutput( '', true );
						instance.logger.error( 'Module [#moduleName#] failed to load!', e );
					}
				}
			}
		</cfscript>
	</cffunction>

	<!--- activateModule --->
	<cffunction name="activateModule" output="false" access="public" returntype="ModuleService" hint="Activate a module">
		<cfargument name="moduleName" type="string" required="true" hint="The name of the module to load. It must exist and be valid. Else we ignore it by logging a warning and returning false."/>
		<cfscript>
			var modules 			= getModuleData();
			var iData       		= {};
			var y					= 1;
			var key					= "";
			var interceptorService  = shell.getInterceptorService();
			var wirebox				= shell.getWireBox();

			// If module not registered, throw exception
			if( NOT structKeyExists( modules, arguments.moduleName ) ){
				throw( message="Cannot activate module: #arguments.moduleName#",
					   detail="The module has not been registered, register the module first and then activate it.",
					   type="ModuleService.IllegalModuleState" );
			}

			// Check if module already activated
			if( modules[ arguments.moduleName ].activated ){
				// Log it
				if( instance.logger.canDebug() ){
					instance.logger.debug( "Module #arguments.moduleName# already activated, skipping activation." );
				}
				return this;
			}

			// Check if module CAN be activated
			if( !modules[ arguments.moduleName ].activate ){
				// Log it
				if( instance.logger.canDebug() ){
					instance.logger.debug( "Module #arguments.moduleName# cannot be activated as it is flagged to not activate, skipping activation." );
				}
				return this;
			}

			// Get module settings
			var mConfig = modules[ arguments.moduleName ];

			// Do we have dependencies to activate first
			if( arrayLen( mConfig.dependencies ) ){
				for( var thisDependency in mConfig.dependencies ){
					if( instance.logger.canDebug() ){
						instance.logger.debug( "Activating #arguments.moduleName# requests dependency activation: #thisDependency#" );
					}
					// Activate dependency first
					activateModule( thisDependency );
				}
			}

			// lock and load baby
			lock name="module.activation.#arguments.moduleName#" type="exclusive" timeout="20" throwontimeout="true"{

				// preModuleLoad interception
				iData = { moduleLocation=mConfig.path,moduleName=arguments.moduleName };
				interceptorService.announceInterception( "preModuleLoad", iData );

				// Register the Config as an observable also.
				interceptorService.registerInterceptor( interceptor=instance.mConfigCache[ arguments.moduleName ], interceptorName="ModuleConfig:#arguments.moduleName#" );

				// Register Models if it exists
				if( directoryExists( mconfig.modelsPhysicalPath ) and mConfig.autoMapModels ){
					// Add as a mapped directory with module name as the namespace with correct mapping path
					var packagePath = ( len( mConfig.cfmapping ) ? mConfig.cfmapping & ".#mConfig.conventions.modelsLocation#" :  mConfig.modelsInvocationPath );
					if( len( mConfig.modelNamespace ) ){
						wirebox.getBinder().mapDirectory( packagePath=packagePath, namespace="@#mConfig.modelNamespace#" );
					} else {
						// just register with no namespace
						wirebox.getBinder().mapDirectory( packagePath=packagePath );
					}
					wirebox.getBinder().processMappings();
				}

				// Register commands if they exist
				if( directoryExists( mconfig.commandsPhysicalPath ) ){
					var commandPath = '/' & replace( mconfig.commandsInvocationPath, '.', '/', 'all' );
					CommandService.initCommands( commandPath, commandPath );
				}

				// Register endpoints if they exist
				if( directoryExists( mconfig.endpointsPhysicalPath ) ){
					var mappedPath = '/' & replace( mconfig.endpointsInvocationPath, '.', '/', 'all' );
					EndpointService.buildEndpointRegistry( mappedPath );
				}

				// Register Interceptors with Announcement service
				for( y=1; y lte arrayLen( mConfig.interceptors ); y++ ){
					interceptorService.registerInterceptor( interceptor=mConfig.interceptors[ y ].class,
														    interceptorProperties=mConfig.interceptors[ y ].properties,
														    interceptorName=mConfig.interceptors[ y ].name);
					// Loop over module interceptors to autowire them
					wirebox.autowire( target=interceptorService.getInterceptor( mConfig.interceptors[ y ].name, true ),
						     		  targetID=mConfig.interceptors[ y ].class );
				}

				// Register module routing entry point pre-pended to routes
				/*if( shell.settingExists( 'sesBaseURL' ) AND len( mConfig.entryPoint ) AND NOT find( ":", mConfig.entryPoint ) ){
					interceptorService.getInterceptor( "SES", true ).addModuleRoutes( pattern=mConfig.entryPoint, module=arguments.moduleName, append=false );
				}*/

				// Call on module configuration object onLoad() if found
				if( structKeyExists( instance.mConfigCache[ arguments.moduleName ], "onLoad" ) ){
					instance.mConfigCache[ arguments.moduleName ].onLoad();
				}

				// postModuleLoad interception
				iData = { moduleLocation=mConfig.path, moduleName=arguments.moduleName, moduleConfig=mConfig };
				interceptorService.announceInterception( "postModuleLoad", iData );

				// Mark it as loaded as it is now activated
				mConfig.activated = true;

				// Now activate any children
				for( var thisChild in mConfig.childModules ){
					activateModule( moduleName=thisChild );
				}

				// Log it
				if( instance.logger.canDebug() ){
					instance.logger.debug( "Module #arguments.moduleName# activated sucessfully." );
				}

			} // end lock

			return this;
		</cfscript>
	</cffunction>

	<!--- reload --->
	<cffunction name="reload" output="false" access="public" returntype="void" hint="Reload a targeted module">
		<cfargument name="moduleName" type="string" required="true" hint="The module to reload"/>
		<cfscript>
			unload(arguments.moduleName);
			registerModule(arguments.moduleName);
			activateModule(arguments.moduleName);
		</cfscript>
	</cffunction>

	<!--- reloadAll --->
	<cffunction name="reloadAll" output="false" access="public" returntype="void" hint="Reload all modules">
		<cfscript>
			unloadAll();
			registerAllModules();
			activateAllModules();
		</cfscript>
	</cffunction>

	<!--- getLoadedModules --->
	<cffunction name="getLoadedModules" output="false" access="public" returntype="array" hint="Get a listing of all loaded modules">
		<cfscript>
			var modules = structKeyList(getModuleData());

			return listToArray(modules);
		</cfscript>
	</cffunction>

	<!--- isModuleRegistered --->
	<cffunction name="isModuleRegistered" output="false" access="public" returntype="boolean" hint="Check and see if a module has been registered">
		<cfargument name="moduleName" required="true" type="string">
		<!--- Verify it in the main settings --->
		<cfreturn structKeyExists( getModuleData(), arguments.moduleName )>
	</cffunction>

	<!--- isModuleActive --->
	<cffunction name="isModuleActive" output="false" access="public" returntype="boolean" hint="Check and see if a module has been activated">
		<cfargument name="moduleName" required="true" type="string">
		<cfscript>
			var modules = getModuleData();
			return ( isModuleRegistered( arguments.moduleName ) and modules[ arguments.moduleName ].activated ? true : false );
		</cfscript>
	</cffunction>

	<!--- unload --->
	<cffunction name="unload" output="false" access="public" returntype="boolean" hint="Unload a module if found from the configuration">
		<cfargument name="moduleName" type="string" required="true" hint="The module name to unload"/>
		<cfscript>
			// This method basically unregisters the module configuration
			var iData = {moduleName=arguments.moduleName};
			var interceptorService = shell.getInterceptorService();
			var x = 1;
			var exceptionUnloading = "";

			// Check if module is loaded?
			if( NOT structKeyExists(getModuleData(),arguments.moduleName) ){ return false; }

		</cfscript>

		<cflock name="module.unload.#arguments.moduleName#" type="exclusive" timeout="20" throwontimeout="true">
		<cfscript>
			// Check if module is loaded?
			if( NOT structKeyExists(getModuleData(),arguments.moduleName) ){ return false; }

			// Before unloading a module interception
			interceptorService.announceInterception( "preModuleUnload",iData);

			// Call on module configuration object onLoad() if found
			if( structKeyExists(instance.mConfigCache[ arguments.moduleName ],"onUnload" ) ){
				try{
					instance.mConfigCache[ arguments.moduleName ].onUnload();
				} catch( Any e ){
					instance.logger.error( "Error unloading module: #arguments.moduleName#. #e.message# #e.detail#", e );
					exceptionUnloading = e;
				}
			}

			// Unregister all interceptors
			for(x=1; x lte arrayLen( getModuleData()[ arguments.moduleName ].interceptors ); x++){
				interceptorService.unregister( getModuleData()[ arguments.moduleName ].interceptors[ x ].name);
			}
			// Unregister Config object
			interceptorService.unregister( "ModuleConfig:#arguments.moduleName#" );

			// Remove SES if enabled.
			/*if( shell.settingExists( "sesBaseURL" ) ){
				interceptorService.getInterceptor( "SES", true ).removeModuleRoutes( arguments.moduleName );
			}*/

			// Remove the possible config names with the ConfigService for auto-completion
			var possibleConfigSettings = [];
			for( var settingName in ConfigService.getPossibleConfigSettings() ) {
				if( !reFindNoCase( '^modules.#arguments.moduleName#.', settingName ) ) {
					possibleConfigSettings.append( settingName );
				}
			}
			ConfigService.setPossibleConfigSettings( possibleConfigSettings );

			// Remove configuration
			structDelete( getModuleData(), arguments.moduleName );

			// Remove Configuration object from Cache
			structDelete( instance.mConfigCache, arguments.moduleName );

			//After unloading a module interception
			interceptorService.announceInterception( "postModuleUnload", iData );

			// Log it
			if( instance.logger.canDebug() ){
				instance.logger.debug( "Module #arguments.moduleName# unloaded successfully." );
			}

			// Do we need to throw exception?
			if( !isSimpleValue( exceptionUnloading ) ){
				throw( exceptionUnloading );
			}
		</cfscript>
		</cflock>

		<cfreturn true>
	</cffunction>

	<!--- unloadAll --->
	<cffunction name="unloadAll" output="false" access="public" returntype="void" hint="Unload all registered modules">
		<cfscript>
			// This method basically unregisters the module configuration
			var modules = getModuleData();
			var key = "";

			// Unload all modules
			for(key in modules){
				unload(key);
			}
		</cfscript>
	</cffunction>

	<!--- loadModuleConfiguration --->
	<cffunction name="loadModuleConfiguration" output="false" access="public" returntype="any" hint="Load the module configuration object and return it">
		<cfargument name="config" 		type="struct" required="true" hint="The module config structure">
		<cfargument name="moduleName"	type="string" required="true" hint="The module name">
		<cfscript>
			var mConfig 	= arguments.config;
			var oConfig 	= createObject( "component", mConfig.invocationPath & ".ModuleConfig" );
			var toLoad 		= "";
			var mixerUtil	= shell.getUtil().getMixerUtil();

			// Decorate It
			oConfig.injectPropertyMixin = mixerUtil.injectPropertyMixin;
			oConfig.getPropertyMixin 	= mixerUtil.getPropertyMixin;

			// MixIn Variables
			oConfig.injectPropertyMixin( "shell", 				shell );
			oConfig.injectPropertyMixin( "moduleMapping", 		mConfig.mapping );
			oConfig.injectPropertyMixin( "modulePath", 			mConfig.path );
			oConfig.injectPropertyMixin( "logBox", 				shell.getLogBox() );
			oConfig.injectPropertyMixin( "log", 				shell.getLogBox().getLogger( oConfig) );
			oConfig.injectPropertyMixin( "wirebox", 			shell.getWireBox() );
			oConfig.injectPropertyMixin( "binder", 				shell.getWireBox().getBinder() );
			oConfig.injectPropertyMixin( "getSystemSetting",	systemSettings.getSystemSetting );
			oConfig.injectPropertyMixin( "getSystemProperty",	systemSettings.getSystemProperty );
			oConfig.injectPropertyMixin( "getEnv",				systemSettings.getEnv );

			// Configure the module
			oConfig.configure();

			// title
			if( !structKeyExists( oConfig, "title" ) ){ oConfig.title = arguments.moduleName; }
			mConfig.title = oConfig.title;
			// aliases
			if( structKeyExists( oConfig, "aliases" ) ){
				// inflate list to array
				if( isSimpleValue( oConfig.aliases ) ){ oConfig.aliases = listToArray( oConfig.aliases ); }
				mConfig.aliases = oConfig.aliases;
			}
			// author
			if( !structKeyExists( oConfig, "author" ) ){ oConfig.author = ""; }
			mConfig.author = oConfig.author;
			// web url
			if( !structKeyExists( oConfig, "webURL" ) ){ oConfig.webURL = ""; }
			mConfig.webURL = oConfig.webURL;
			// description
			if( !structKeyExists( oConfig, "description" ) ){ oConfig.description = ""; }
			mConfig.description	= oConfig.description;
			// version
			if( !structKeyExists( oConfig, "version" ) ){ oConfig.version = ""; }
			mConfig.version	= oConfig.version;
			// cf mapping
			if( structKeyExists( oConfig, "cfmapping" ) ){
				mConfig.cfmapping = oConfig.cfmapping;
			}
			// model namespace override
			if( structKeyExists( oConfig, "modelNamespace" ) ){
				mConfig.modelNamespace = oConfig.modelNamespace;
			}
			// Auto map models
			if( structKeyExists( oConfig, "autoMapModels" ) ){
				mConfig.autoMapModels = oConfig.autoMapModels;
			}
			// Dependencies
			if( structKeyExists( oConfig, "dependencies" ) ){
				// set it always as an array
				mConfig.dependencies = isSimpleValue( oConfig.dependencies ) ? listToArray( oConfig.dependencies ) : oConfig.dependencies;
			}
			// Disabled
			mConfig.disabled = false;
			if( structKeyExists( oConfig,"disabled" ) ){
				mConfig.disabled = oConfig.disabled;
			}
			// Activated
			mConfig.activate = true;
			if( structKeyExists( oConfig,"activate" ) ){
				mConfig.activate = oConfig.activate;
			}

			//Get the parent settings
			mConfig.parentSettings = oConfig.getPropertyMixin( "parentSettings", "variables", {} );
			//Get the module settings
			mConfig.settings = oConfig.getPropertyMixin( "settings", "variables", {} );
			// Override with CommandBox config settings
			overrideConfigSettings( mConfig.settings, moduleName );

			// Register the possible config names with the ConfigService for auto-completion
			var possibleConfigSettings = ConfigService.getPossibleConfigSettings();
			for( var settingName in mConfig.settings ) {
				possibleConfigSettings.append( 'modules.#moduleName#.#settingName#' );
			}
			ConfigService.setPossibleConfigSettings( possibleConfigSettings );

			//Get Interceptors
			mConfig.interceptors = oConfig.getPropertyMixin( "interceptors", "variables", [] );
			for(var x=1; x lte arrayLen( mConfig.interceptors ); x=x+1){
				//Name check
				if( NOT structKeyExists(mConfig.interceptors[x],"name" ) ){
					mConfig.interceptors[x].name = listLast(mConfig.interceptors[x].class,"." );
				}
				//Properties check
				if( NOT structKeyExists(mConfig.interceptors[x],"properties" ) ){
					mConfig.interceptors[x].properties = structnew();
				}
			}

			//Get custom interception points
			mConfig.interceptorSettings = oConfig.getPropertyMixin( "interceptorSettings","variables",structnew());
			if( NOT structKeyExists(mConfig.interceptorSettings,"customInterceptionPoints" ) ){
				mConfig.interceptorSettings.customInterceptionPoints = "";
			}

			// Get and Append Module conventions
			structAppend( mConfig.conventions, oConfig.getPropertyMixin( "conventions", "variables", {} ), true );

			return oConfig;
		</cfscript>
	</cffunction>

	<!--- overrideConfigSettings --->
	<cffunction name="overrideConfigSettings" output="false" access="public">
		<cfargument name="moduleSettings" 		type="struct" required="true" hint="The module setting structure">
		<cfargument name="moduleName"	type="string" required="true" hint="The module name">
		<cfscript>
			configSettings = ConfigService.getConfigSettings();
			if( structKeyExists( configSettings, 'modules' ) && structKeyExists( configSettings.modules, arguments.moduleName ) ) {
				arguments.moduleSettings.append( configSettings.modules[ arguments.moduleName ] );
			}
		</cfscript>
	</cffunction>

	<!--- overrideAllConfigSettings --->
	<cffunction name="overrideAllConfigSettings" output="false" access="public">
		<cfscript>
			for( var moduleName in getLoadedModules() ) {
				overrideConfigSettings( getModuleData()[ moduleName ].settings, moduleName );
			}
		</cfscript>
	</cffunction>


<!------------------------------------------- PRIVATE ------------------------------------------->

	<!--- buildRegistry --->
    <cffunction name="buildRegistry" output="false" access="private" returntype="void" hint="Build the modules registry">
    	<cfargument name="locations" type="array" 	required="true" hint="The array of locations to register"/>
		<cfscript>
			var locLen = arrayLen( arguments.locations );

			for(var x=1; x lte locLen; x++){
				if( len( trim( arguments.locations[ x ] ) ) ){
					// Get all modules found in the module location and append to module registry, only new ones are added
					scanModulesDirectory( arguments.locations[ x ] );
				}
			}
		</cfscript>
    </cffunction>

	<!--- scanModulesDirectory --->
	<cffunction name="scanModulesDirectory" output="false" access="private" returntype="void" hint="Get an array of modules found and add to the registry structure">
		<cfargument name="dirPath" 			type="string" required="true" hint="Path to scan"/>
		<cfset var q = "">
		<cfset var expandedPath = expandPath( arguments.dirpath )>

		<cfdirectory action="list" directory="#expandedPath#" name="q" type="dir" sort="asc">

		<cfloop query="q">
			<cfif NOT find( ".", q.name )>
				<!--- Add only if it does not exist, so location preference kicks in --->
				<cfif  NOT structKeyExists(instance.moduleRegistry, q.name)>
					<cfset instance.moduleRegistry[q.name] = {
						locationPath 	= arguments.dirPath,
						physicalPath 	= expandedPath,
						invocationPath 	= replace( reReplace(arguments.dirPath,"^/","" ), "/", ".","all" )
					}>
				<cfelse>
					<cfset instance.logger.debug( "Found duplicate module: #q.name# in #arguments.dirPath#. Skipping its registration in our module registry, order of preference given." ) >
				</cfif>
			</cfif>
		</cfloop>

	</cffunction>

	<!--- canLoad --->
    <cffunction name="canLoad" output="false" access="private" returntype="boolean" hint="Checks if the module can be loaded or registered">
  		<cfargument name="moduleName" type="string" required="true" hint="The module name"/>
  		<cfscript>
    		var excludeModules = ArrayToList( ConfigService.getSetting( "ModulesExclude", [] ) );

			// If we have excludes and in the excludes
			if( len( excludeModules ) and listFindNoCase( excludeModules, arguments.moduleName ) ){
				instance.logger.info( "Module: #arguments.moduleName# excluded from loading." );
				return false;
			}

			return true;
    	</cfscript>
    </cffunction>

</cfcomponent>
