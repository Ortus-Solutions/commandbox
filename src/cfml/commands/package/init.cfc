/**
 * Initialize a package in the current directory by creating a default box.json file.
 * 
 * init
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="init" excludeFromHelp=false {

	property name="PackageService" inject="PackageService";

	/**
	 * @packageName.hint The humnan-readable name for this package 
	 * @slug.hint The ForgeBox slug for this package (no spaces or special chars)
	 * @directory.hint The location to initialize the project.  Defaults to the current working directory.
	 * @force.hint Do not prompt, overwrite if exists
	 **/
	function run( packageName='myApplication', slug='mySlug', directory='', Boolean force=false ) {
		
		// This will make each directory canonical and absolute		
		arguments.directory = fileSystemUtil.resolvePath( '' );
		
		// Validate directory
		if( !directoryExists( arguments.directory ) ) {
			return error( 'Directory #arguments.directory# does not exist.' );
		}
		
		// Spin up a new box.json with our defaults
		var boxJSON = PackageService.newPackageDescriptor( { "name" : arguments.packageName, "slug" : arguments.slug } );
		
		// This is where we will write the box.json file
		var boxfile = arguments.directory & "/box.json";
	
		// If the file doesn't exist, or we are forcing, just do it!
		if( !fileExists( boxfile ) || force ) {
			PackageService.writePackageDescriptor( boxJSON, arguments.directory );
			
			print.greenLine( 'Package Initialized!' );
			print.greenLine( 'Created ' & boxfile );
			
		// File exists, better check first
		} else {
			// Ask the user what they want to do
			if( confirm( '#boxfile# already exists, overwrite? [y/n]') ) {
				PackageService.writePackageDescriptor( boxJSON, arguments.directory );
				
				print.greenLine( 'Package Initialized!' );
				print.line( boxfile );
			} else {
				print.redLine( 'cancelled' );		
			}
			
		}
		
	}

}