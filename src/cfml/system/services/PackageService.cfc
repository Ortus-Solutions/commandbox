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
	property name="formatterUtil" inject="formatter";

	/**
	* Constructor
	*/
	function init(){
		return this;
	}
	
	/**
	* Checks to see if a box.json exists in a given directory
	* @directory.hint The directory to examine
	*/	
	public function isPackage( required string directory ) {
		// If the packge has a box.json in the root...
		return fileExists( getDescriptorPath( arguments.directory ) );
	}
	
	/**
	* Returns the path to the package descriptor
	* @directory.hint The directory that is the root of the package
	*/	
	public function getDescriptorPath( required string directory ) {
		return directory & '/box.json';
	}
	
	/**
	* Adds a dependency to a packge
	* @directory.hint The directory that is the root of the package
	* @dev.hint True if this is a development depenency, false if it is a production dependency
	*/	
	public function addDependency( required string directory, required string packageName, required string version,  boolean dev=false ) {
		// Get box.json, create empty if it doesn't exist
		var boxJSON = readPackageDescriptor( arguments.directory );
		// Get reference to appropriate depenency struct
		var dependencies = ( arguments.dev ? boxJSON.devDependencies : boxJSON.dependencies );
		
		// Add/overwrite this dependency
		dependencies[ arguments.packageName ] = arguments.version;
		
		// Write the box.json back out
		writePackageDescriptor( boxJSON, arguments.directory );		
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
		
		// If the packge has a box.json in the root...
		if( isPackage( arguments.directory ) ) {
			
			// ...Read it.
			boxJSON = fileRead( getDescriptorPath( arguments.directory ) );
			
			// Validate the file is valid JSOn
			if( isJSON( boxJSON ) ) {
				// Merge this JSON with defaults
				return newPackageDescriptor( deserializeJSON( boxJSON ) );
			}
			
		}
		
		// Just return defaults
		return newPackageDescriptor();	
	}

	/**
	* Write the box.json data as a JSON file
	* @JSONData.hint The JSON data to write to the file. Can be a struct, or the string JSON
	* @directory.hint The directory to write the box.json
	*/
	function writePackageDescriptor( required any JSONData, required directory ){
		
		if( !isSimpleValue( JSONData ) ) {
			JSONData = serializeJSON( JSONData );
		}

		fileWrite( getDescriptorPath( arguments.directory ), formatterUtil.formatJSON( JSONData ) );	
	}


	// Dynamic completion for property name based on contents of box.json
	function completeProperty( required directory ) {
		var props = [];
		
		// Check and see if box.json exists
		if( isPackage( arguments.directory ) ) {
			boxJSON = readPackageDescriptor( arguments.directory );
			props = addProp( props, '', boxJSON );			
		}
		return props;		
	}
	
	// Recursive function to crawl box.json and create a string that represents each property.
	private function addProp( props, prop, boxJSON ) {
		var propValue = ( len( prop ) ? evaluate( 'boxJSON.#prop#' ) : boxJSON );
		
		if( isStruct( propValue ) ) {
			// Add all of this struct's keys
			for( var thisProp in propValue ) {
				var newProp = listAppend( prop, thisProp, '.' );
				props.append( newProp );
				props = addProp( props, newProp, boxJSON );
			}			
		}
		
		if( isArray( propValue ) ) {
			// Add all of this array's indexes
			var i = 0;
			while( ++i <= propValue.len() ) {
				var newProp = '#prop#[#i#]';
				props.append( newProp );
				props = addProp( props, newProp, boxJSON );
			}
		}
		
		return props;
	}


}