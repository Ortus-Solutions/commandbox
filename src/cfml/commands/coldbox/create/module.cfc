/**
* Create a new module in an existing ColdBox application.  Make sure you are running this command in the root
* of your app for it to find the correct folder.
* .
* {code:bash}
* coldbox create module myModule
* {code}  
*  
 **/
component extends='commandbox.system.BaseCommand' aliases='' excludeFromHelp=false {
		
	/**
	* @name.hint Name of the module to create.
	* @author.hint Whoever wrote this module
	* @authorURL.hint The author's URL
	* @version.hint The symantic version number: major.minior.patch
	* @cfmapping.hint A CF app mapping to create that points to the root of this module
	* @modelNamespace.hint The namespace to use when mapping the models in this module
	* @directory.hint The base directory to create your model in. 
	 **/
	function run( 	required name,
					author='',
					authorURL='',
					version='1.0.0',
					cfmapping='',
					modelNamespace='',
					directory='modules' ) {						
		// This will make each directory canonical and absolute		
		directory = fileSystemUtil.resolvePath( directory );
		
		// Validate directory
		if( !directoryExists( directory ) ) {
			return error( 'The directory [#directory#] doesn''t exist.' );			
		}
		// This help readability so the success messages aren't up against the previous command line
		print.line();
				
		// Script?
		var scriptPrefix = '';
		// TODO: Pull this from box.json
		var script = true;
		if( script ) {
			scriptPrefix = 'Script';	
		}
		var description = '';
		
		// Read in Module Config
		var moduleConfig = fileRead( '/commandbox/templates/modules/ModuleConfig#scriptPrefix#.cfc' );
		
		// Start Generation Replacing
		moduleConfig = replaceNoCase( moduleConfig, '@title@', name, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@author@', author, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@authorURL@', authorURL, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@description@', description, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@version@', version, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@cfmapping@', cfmapping, 'all');
		moduleConfig = replaceNoCase( moduleConfig, '@modelNamespace@', modelNamespace, 'all');
		
		// Copy module template
		directoryCopy( '/commandbox/templates/modules/', directory & '/#name#', true );
		
		// Clean Files Out
		if( script ) {
			fileDelete( directory & '/#name#/handlers/Home.cfc' );
			fileMove( directory & '/#name#/handlers/HomeScript.cfc', directory & '/#name#/handlers/Home.cfc' );
		} else {
			fileDelete( directory & '/#name#/handlers/HomeScript.cfc' );
		}
		fileDelete( directory & '/#name#/ModuleConfigScript.cfc' );
			
		// Write Out the New Config
		fileWrite( directory & '/#name#/ModuleConfig.cfc', moduleConfig );
		
		var stuffAdded = directoryList( directory & '/#name#', true );
		print.greenLine( 'Created ' & directory & '/#name#' );
		for( var thing in stuffAdded ) {
			print.greenLine( 'Created ' & thing );			
		}
		
								
	}

}