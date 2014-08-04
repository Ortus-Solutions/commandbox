/**
*  This will create a blank ColdBox app from one of our app skeletons.  By default it will create
*  in your current directory.  Use the "pwd" command to find out what directory you're currently in.
*  You can choose what app skeleton to use as well as override the directory it's created in.
*  The built-in app skeletons are located in the .commandbox/cfml/skeltons directory and include:
*  .
*  - Advanced
*  - AdvancedScript (default)
*  - Simple
*  - SuperSimple
* .
* coldbox create app myApp --installColdBox
*
**/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	// DI
	property name="packageService" 	inject="PackageService";
	property name='parser' 	inject='Parser';
	
	variables.skeletonLocation = expandPath( '\commandbox\skeletons\' );
	
	/**
	 * @name.hint The name of the app you want to create
	 * @skeleton.hint The name of the app skeleton to generate 
	 * @directory.hint The directory to create the app in.  Defaults to your current working directory.
	 * @init.hint "init" the directory as a package if it isn't already
	 * @installColdBox.hint Install the latest stable version of ColdBox from ForgeBox
	 **/
	function run(
				required name,
				skeleton='AdvancedScript',
				directory=getCWD(),
				boolean init=true,
				boolean installColdBox=false ) {
					
		// This will make the directory canonical and absolute		
		directory = fileSystemUtil.resolvePath( directory );
		
		var skeletonZip = skeletonLocation & skeleton & '.zip';
		
		// Validate directory
		if( !directoryExists( directory ) ) {
			return error( 'The directory [#directory#] doesn''t exist.' );			
		}
		// Validate skeleton
		if( !fileExists( skeletonZip ) ) {
			var options = directoryList( path=skeletonLocation, listInfo='name', sort="name" );
			return error( "The app skeleton [#skeletonZip#] doesn't exist.  Valid options are #replaceNoCase( arrayToList( options, ', ' ), '.zip', '', 'all' )#" );			
		}
		
		// Unzip the skeleton!
		zip
			action="unzip"
			destination="#directory#"
			file="#skeletonZip#";
	
		print.line();
		print.greenLine( '#skeleton# Application successfully created in [#directory#]' );
		
		// Init, if not a package
		if( arguments.init && !packageService.isPackage( arguments.directory ) ) {
			var originalPath = getCWD(); 
			// init must be run from CWD
			shell.cd( arguments.directory );
			runCommand( 'init "#parser.escapeArg( arguments.name )#" "#parser.escapeArg( replace( arguments.name, ' ', '', 'all' ) )#"' ); 
			shell.cd( originalPath );
		}
		
		// Install the ColdBox platform
		if( arguments.installColdBox ) {
			
			// Flush out stuff from above
			print.toConsole();
			
			packageService.installPackage(
				ID = 'coldbox-platform',
				directory = arguments.directory,
				save = true,
				saveDev = false,
				production = true,
				currentWorkingDirectory = arguments.directory
			);
		}
		
	}

}