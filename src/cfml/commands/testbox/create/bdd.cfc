/**
* This will create a new BDD spec in the requested folder but you can 
* override that with the directory param as well.
*  
**/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	/**
	* @name.hint Name of the BDD spec to create without the .cfc. For packages, specify name as 'myPackage/myBDDSpec'
	* @open.hint Open the file once it is created
	* @directory.hint The base directory to create your BDD spec in
	 **/
	function run( required name, boolean open=false, directory=getCWD() ){
		// This will make each directory canonical and absolute		
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
						
		// Validate directory
		if( !directoryExists( arguments.directory ) ) {
			return error( 'The directory [#arguments.directory#] doesn''t exist.' );			
		}
		
		// Allow dot-delimited paths
		arguments.name = replace( arguments.name, '.', '/', 'all' );
		
		// This help readability so the success messages aren't up against the previous command line
		print.line();
		
		// Read in Templates
		var BDDContent = fileRead( '/commandbox/templates/testbox/bdd.txt' );
				
		// Write out BDD Spec
		var BDDPath = '#directory#/#name#.cfc'; 
		file action='write' file='#BDDPath#' mode ='777' output='#BDDContent#';
		print.greenLine( 'Created #BDDPath#' );

		// Open file?
		if( arguments.open ){ runCommand( "edit #bddPath#" ); }			
	}

}