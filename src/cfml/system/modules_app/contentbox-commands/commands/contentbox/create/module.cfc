/**
* Create a new module in an existing ColdBox application.  Make sure you are running this command in the root
* of your app for it to find the correct folder.
* .
* {code:bash}
* coldbox create module myModule
* {code}  
*  
 **/
component {
		
	/**
	* @name Name of the module to create.
	* @author Whoever wrote this module
	* @authorURL The author's URL
	* @description The description for this module
	* @version The symantic version number: major.minior.patch
	* @cfmapping A CF app mapping to create that points to the root of this module
	* @modelNamespace The namespace to use when mapping the models in this module
	* @dependencies The list of dependencies for this module
	* @directory The base directory to create your model in and creates the directory if it does not exist. 
	* @script.hint Generate content in script markup or tag markup
	**/
	function run( 	
		required name,
		author='',
		authorURL='',
		description="",
		version='1.0.0',
		cfmapping=arguments.name,
		modelNamespace=arguments.name,
		dependencies="",
		directory='modules/contentbox/modules_user',
		boolean script=true
	){						
		// This will make each directory canonical and absolute		
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		
		// Validate directory
		if( !directoryExists( arguments.directory ) ) {
			directoryCreate( arguments.directory );			
		}
		// This help readability so the success messages aren't up against the previous command line
		print.line();
				
		// Script?
		var scriptPrefix = '';
		// TODO: Pull this from box.json
		if( arguments.script ) {
			scriptPrefix = 'Script';	
		}
		
		// Read in Module Config
		var moduleConfig = fileRead( '/coldbox-commands/templates/modules/ModuleConfig#scriptPrefix#.cfc' );
		
		// Start Generation Replacing
		moduleConfig = replaceNoCase( moduleConfig, '@title@', arguments.name, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@author@', arguments.author, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@authorURL@', arguments.authorURL, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@description@', arguments.description, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@version@', arguments.version, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@cfmapping@', arguments.cfmapping, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@modelNamespace@', arguments.modelNamespace, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@dependencies@', serializeJSON( listToArray( arguments.dependencies ) ), 'all');
		
		// Copy module template
		directoryCopy( '/coldbox-commands/templates/modules/', arguments.directory & '/#arguments.name#', true );
		
		// Clean Files Out
		if( script ) {
			fileDelete( arguments.directory & '/#arguments.name#/handlers/Home.cfc' );
			fileMove( arguments.directory & '/#arguments.name#/handlers/HomeScript.cfc', arguments.directory & '/#arguments.name#/handlers/Home.cfc' );
		} else {
			fileDelete( arguments.directory & '/#arguments.name#/handlers/HomeScript.cfc' );
		}
		fileDelete( arguments.directory & '/#arguments.name#/ModuleConfigScript.cfc' );
			
		// Write Out the New Config
		fileWrite( arguments.directory & '/#arguments.name#/ModuleConfig.cfc', moduleConfig );
		
		var stuffAdded = directoryList( arguments.directory & '/#arguments.name#', true );
		print.greenLine( 'Created ' & arguments.directory & '/#arguments.name#' );
		for( var thing in stuffAdded ) {
			print.greenLine( 'Created ' & thing );			
		}
								
	}

}
