/**
* This will create a new layout in an existing ColdBox application.  Make sure you are running this command in the root
* of your app for it to find the correct folder.  By default, your new layout will be created in /layouts but you can 
* override that with the directory param.    
*  
**/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	/**
	* @name.hint Name of the layout to create without the .cfm.
	* @helper.hint Generate a helper file for this layout
	* @directory.hint The base directory to create your layout in.
	 **/
	function run( 	required name,
					boolean helper=false,
					directory='layouts' ) {
		// This will make each directory canonical and absolute		
		directory = fileSystemUtil.resolveDirectory( directory );
						
		// Validate directory
		if( !directoryExists( directory ) ) {
			return error( 'The directory [#directory#] doesn''t exist.' );			
		}
		
		var layoutContent = '<h1>#name# Layout</h1>#CR#<cfoutput>##renderView()##</cfoutput>';
		var layoutHelperContent = '<!--- #name# Layout Helper --->';
		
		// Write out layout
		var layoutPath = '#directory#/#name#.cfm'; 
		file action='write' file='#layoutPath#' mode ='777' output='#layoutContent#';
		print.greenLine( 'Created #layoutPath#' );				
		
		if( helper ) {
			// Write out layout helper
			var layoutHelperPath = '#directory#/#name#Helper.cfm'; 
			file action='write' file='#layoutHelperPath#' mode ='777' output='#layoutHelperContent#';
			print.greenLine( 'Created #layoutHelperPath#' );
			
		}
	
	}

}