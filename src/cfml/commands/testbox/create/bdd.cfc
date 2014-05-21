/**
* This will create a new BDD spec in an existing TestBox-enabled application.  Make sure you are running this command in the root
* of your app for it to find the correct folder.  By default, your new BDD spec will be created in /tests/specs but you can 
* override that with the directory param.    
*  
**/
component extends="commandbox.system.BaseCommand" aliases="coldbox create bdd" excludeFromHelp=false {
	
	/**
	* @name.hint Name of the BDD spec to create without the .cfc. For packages, specify name as 'myPackage/myBDDSpec'
	* @directory.hint The base directory to create your BDD spec in
	 **/
	function run( 	required name,
					directory='tests/specs' ) {
		// This will make each directory canonical and absolute		
		directory = fileSystemUtil.resolveDirectory( directory );
						
		// Validate directory
		if( !directoryExists( directory ) ) {
			return error( 'The directory [#directory#] doesn''t exist.' );			
		}
		
		// Allow dot-delimited paths
		name = replace( name, '.', '/', 'all' );
		
		// This help readability so the success messages aren't up against the previous command line
		print.line();
		
		
		// Read in Templates
		var BDDContent = fileRead( '/commandbox/templates/testbox/bdd.txt' );
				
		// Write out BDD Spec
		var BDDPath = '#directory#/#name#.cfc'; 
		file action='write' file='#BDDPath#' mode ='777' output='#BDDContent#';
		print.greenLine( 'Created #BDDPath#' );				
	
	
	}

}