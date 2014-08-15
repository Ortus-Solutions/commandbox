/**
 * Initialize a package in the current directory by creating a default box.json file.
 * 
 * init
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	property name="PackageService" inject="PackageService";
	property name="formatterUtil" inject="formatter";

	/**
	 * @packageName.hint The humnan-readable name for this package 
	 * @slug.hint The ForgeBox slug for this package (no spaces or special chars)
	 * @directory.hint The location to initialize the project.  Defaults to the current working directory.
	 * @force.hint Do not prompt, overwrite if exists
	 **/
	function run( packageName='myApplication', slug='mySlug', directory='', Boolean force=false ) {
		if( !len( directory ) ) {
			directory = shell.pwd();
		}
		
		// Validate directory
		if( !directoryExists( directory ) ) {
			// create the directory 
			directoryCreate( directory );
		}
		
		// Spin up a new box.json with our defaults
		var boxJSON = PackageService.newPackageDescriptor( { "name" : arguments.packageName, "slug" : arguments.slug } );
		
		// Clean up directory
		if( listFind( '\,/', right( directory, 1 ) ) ) {
			directory = mid( directory, 1, len( directory )-1  );
		}
		
		// This is where we will write the box.json file
		var boxfile = directory & "/box.json";
	
		// If the file doesn't exist, or we are forcing, just do it!
		if( !fileExists( boxfile ) || force ) {
			fileWrite( boxfile, formatterUtil.formatJson( boxJSON ) );
			
			print.greenLine( 'Package Initialized!' );
			print.greenLine( 'Created ' & boxfile );
			
		// File exists, better check first
		} else {
			// Ask the user what they want to do
			if( confirm( '#boxfile# already exists, overwrite? [y/n]') ) {
				fileWrite( boxfile, formatterUtil.formatJson( boxJSON ) );
				
				print.greenLine( 'Package Initialized!' );
				print.line( boxfile );
			} else {
				print.redLine( 'cancelled' );		
			}
			
		}
		
	}

}