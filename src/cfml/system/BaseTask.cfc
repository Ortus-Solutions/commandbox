/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the base task implementation.  An abstract class if you will.
*
*/
component accessors="true" extends='commandbox.system.BaseCommand' {

	// Tasks mostly just do everything commands do


	/**
	 * Return a new PropertyFile instance
 	 **/
	function propertyFile( propertyFilePath='' ) {
		var propertyFile = wirebox.getInstance( 'propertyFile@propertyFile' );
		
		// If the user passed a propertyFile path
		if( propertyFilePath.len() ) {
			
			// Make relative paths resolve to the current folder that the task lives in.
			propertyFilePath = fileSystemUtil.resolvePath( 
									propertyFilePath,
									getDirectoryFromPath( getCurrentTemplatePath() )
								);
			
			// If it exists, go ahead and load it now
			if( fileExists( propertyFilePath ) ){
				propertyFile.load( propertyFilePath );
			} else {
				// Otherwise, just set it so it can be used later on save.
				propertyFile
					.setPath( propertyFilePath );
			}
			
		}
		return propertyFile;
	}

}
