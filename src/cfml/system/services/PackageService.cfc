/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle working with the box.json file
*/
component accessors="true" singleton {

	// DI 
	property name="shell" inject="shell";

	/**
	* Constructor
	*/
	function init(){
		return this;
	}
	
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

	/**
	* Get the box.json as data from the passed directory location, if not found
	* then we return an empty struct
	* @directory.hint The directory to search for the box.json
	*/
	struct function readPackageDescriptor( required directory ){

		var boxJSONPath = directory & '/box.json';
		
		// If the packge has a box.json in the root...
		if( fileExists( boxJSONPath ) ) {
			
			// ...Read it.
			boxJSON = fileRead( boxJSONPath );
			
			// Validate the file is valid JSOn
			if( isJSON( boxJSON ) ) {
				// Merge this JSON with defaults
				return newPackageDescriptor( deserializeJSON( boxJSON ) );
			}
			
		}
		
		// Just return defaults
		return newPackageDescriptor();	
	}

}