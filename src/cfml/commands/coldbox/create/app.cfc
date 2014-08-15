/**
*  This will create a blank ColdBox app from one of our app skeletons.  By default it will creat
*  in your current directory.  Use the "pwd" command to find out what directory you're currently in.
*  You can choose what app skeleton to use as well as override the directory it's created in.
*  The built-in app skeletons are located in the .commandbox/cfml/skeltons directory and include:
*  -
*  - Advanced
*  - AdvancedScript (default)
*  - Simple
*  - SuperSimple
*
**/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	variables.skeletonLocation = expandPath( '\commandbox\skeletons\' );
	
	/**
	 * @name.hint The name of the app you want to create
	 * @skeleton.hint The name of the app skeleton to generate 
	 * @directory.hint The directory to create the app in.  Defaults to your current working directory.
	 **/
	function run(
				required name,
				skeleton='AdvancedScript',
				directory=shell.pwd() ) {
					
		// This will make the directory canonical and absolute		
		directory = fileSystemUtil.resolvePath( directory );
		
		var skeletonZip = skeletonLocation & skeleton & '.zip';
		
		// Validate directory
		if( !directoryExists( directory ) ) {
			// create the directory 
			directoryCreate( directory );			
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
		
	}

}