/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* Helper class for dealing with packages.  Kind of like a service, just not as comprehensive :)
* Conssider creating a transient package model for some of this logic
*
*/
component singleton {
	
	/**
	* Get the default package description, AKA box.json
	* @defaults.hint A struct of default values to be merged into the empty, default document
	*/	
	public function newPackageDescriptor( struct defaults={} ) {
		
		// TODO: Get author info from default CommandBox config
		
		// Read the default JSON file and deserialize it.  
		var boxJSON = DeserializeJSON( fileRead( '/commandBox/templates/box.json.txt' ) );
		
		// Replace things passed via parameters
		boxJSON = boxJSON.append( arguments.defaults );
		
		return boxJSON; 
		
	}
	
}