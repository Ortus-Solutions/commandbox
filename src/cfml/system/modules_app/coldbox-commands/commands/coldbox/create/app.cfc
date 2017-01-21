/**
*  Create a blank ColdBox app from one of our app skeletons or a skeleton using a valid Endpoint ID which can come from .
*  ForgeBox, HTTP/S, git, github, etc.
*  By default it will create the application in your current directory.
* .
* {code:bash}
* coldbox create app myApp
* {code}
* .
*  Here are the basic skeletons that are available for you that come from ForgeBox
*  - Advanced
*  - AdvancedScript (default)
*  - elixir
*  - elixir-bower
*  - elixir-vuejs
*  - rest
*  - Simple
*  - SuperSimple
* .
* {code:bash}
* coldbox create app skeleton=rest
* {code}
* .
* The skeleton parameter can also be any valid Endpoint ID, which includes a Git repo or HTTP URL pointing to a package.
* .
* {code:bash}
* coldbox create app skeleton=http://site.com/myCustomAppTemplate.zip
* {code}
* .
* Use the "installColdBox" parameter to install the latest stable version of ColdBox from ForgeBox
* {code:bash}
* coldbox create app myApp --installColdBox
* {code}
* .
* Use the "installTestBox" parameter to install the latest stable version of TestBox from ForgeBox
* {code:bash}
* coldbox create app myApp --installColdBox --installTestBox
* {code}
* 
**/
component {

	// DI
	property name="packageService" 	inject="PackageService";
	
	/**
	* Constructor
	*/
	function init(){
		
		// Map these shortcut names to the actual ForgeBox slugs
		variables.templateMap = {
			'Advanced'			= 'cbtemplate-advanced',
			'AdvancedScript'	= 'cbtemplate-advanced-script',
			'ElixirVueJS'		= 'cbtemplate-elixir-vuejs',
			'ElixirBower'		= 'cbtemplate-elixir-bower',
			'Elixir'			= 'cbtemplate-elixir',
			'rest'				= 'cbtemplate-rest',
			'Simple'			= 'cbtemplate-simple',
			'SuperSimple'		= 'cbtemplate-supersimple'			
		};
		
		return this;
	}
	
	/**
	 * @name The name of the app you want to create
	 * @skeleton The name of the app skeleton to generate (or an endpoint ID like a forgebox slug)
	 * @skeleton.optionsUDF skeletonComplete
	 * @directory The directory to create the app in and creates the directory if it does not exist.  Defaults to your current working directory.
	 * @init "init" the directory as a package if it isn't already
	 * @installColdBox Install the latest stable version of ColdBox from ForgeBox
	 * @installColdBoxBE Install the bleeding edge version of ColdBox from ForgeBox
	 * @installTestBox Install the latest stable version of TestBox from ForgeBox
	 * @wizard Run the ColdBox Creation wizard
	 * @initWizard Run the init creation package wizard
	 **/
	function run(
		name="My ColdBox App",
		skeleton='AdvancedScript',
		directory=getCWD(),
		boolean init=true,
		boolean installColdBox=false,
		boolean installColdBoxBE=false,
		boolean installTestBox=false,
		boolean wizard=false,
		boolean initWizard=false
	) {
		
		// Check for wizard argument
		if( arguments.wizard ){
			runCommand( 'coldbox create app-wizard' );
			return;
		}

		// This will make the directory canonical and absolute
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		
		// Validate directory, if it doesn't exist, create it.
		if( !directoryExists( arguments.directory ) ) {
			directoryCreate( arguments.directory );
		}

		// If the skeleton is one of our "shortcut" names
		if( variables.templateMap.keyExists( arguments.skeleton ) ) {
			// Replace it with the actual ForgeBox slug name.
			arguments.skeleton = variables.templateMap[ arguments.skeleton ];
		}

		// Install the skeleton
		packageService.installPackage(
			ID = arguments.skeleton,
			directory = arguments.directory,
			save = false,
			saveDev = false,
			production = true,
			currentWorkingDirectory = arguments.directory
		);
		
		// Check for the @appname@ in .project files
		if( fileExists( "#arguments.directory#/.project" ) ){
			var sProject = fileRead( "#arguments.directory#/.project" );
			sProject = replaceNoCase( sProject, "@appName@", arguments.name, "all" );
			file action='write' file='#arguments.directory#/.project' mode ='755' output='#sProject#';
		}

		// Init, if not a package as a Box Package
		if( arguments.init && !packageService.isPackage( arguments.directory ) ) {
			var originalPath = getCWD(); 
			// init must be run from CWD
			shell.cd( arguments.directory );
			command( 'init' )
				.params(
					name=arguments.name, 
					slug=replace( arguments.name, ' ', '', 'all' ),
					wizard=arguments.initWizard )
				.run(); 
			shell.cd( originalPath );
		}
		
		// Install the ColdBox platform
		if( arguments.installColdBox || arguments.installColdBoxBE ) {
			
			// Flush out stuff from above
			print.toConsole();
			
			packageService.installPackage(
				ID = 'coldbox#iif( arguments.installColdBoxBE, de( '-be' ), de( '' ) )#',
				directory = arguments.directory,
				save = true,
				saveDev = false,
				production = true,
				currentWorkingDirectory = arguments.directory
			);
		}

		// Install TestBox
		if( arguments.installTestBox ) {
			
			// Flush out stuff from above
			print.toConsole();
			
			packageService.installPackage(
				ID = 'testbox',
				directory = arguments.directory,
				save = false,
				saveDev = true,
				production = true,
				currentWorkingDirectory = arguments.directory
			);
		}
		
	}

	/**
	* Returns an array of coldbox skeletons available
	*/
	function skeletonComplete( ) {
		return variables.templateMap.keyList().listToArray();
	}

}