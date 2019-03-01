/**
* I am a new Model Object
*/
component accessors="true"{
	
	// Properties
	property name='javaPropertyFile';
	// A fully qualified path to a property file
	property name='path';
	property name='syncedNames';
	

	/**
	 * Constructor
	 */
	PropertyFile function init(){
		setSyncedNames( [] );
		setJavaPropertyFile( createObject( 'java', 'java.util.Properties' ).init() );
		return this;
	}
	
	/**
	* @load A fully qualified path to a property file
	*/
	function load( required string path){
		setPath( arguments.path );
		var fis = CreateObject( 'java', 'java.io.FileInputStream' ).init( path );
		var BOMfis = CreateObject( 'java', 'org.apache.commons.io.input.BOMInputStream' ).init( fis );
		var propertyFile = getJavaPropertyFile();
		propertyFile.load( BOMfis );
		BOMfis.close();
		
		
		var props = propertyFile.propertyNames();
		var syncedNames = getSyncedNames();
		while( props.hasMoreElements() ) {
			var prop = props.nextElement();
			this[ prop ] = get( prop );
			syncedNames.append( prop ); 
		}
		setSyncedNames( syncedNames );
		
		return this;
	}

	/**
	* @load A fully qualified path to a property file.  File will be created if it doesn't exist.
	*/
	function store( string path=variables.path ){
		syncProperties();
		
		if( !fileExists( arguments.path ) ) {
			directoryCreate( getDirectoryFromPath( arguments.path ), true, true );
			fileWrite( arguments.path, '' );
		}
		
		var fos = CreateObject( 'java', 'java.io.FileOutputStream' ).init( arguments.path );
		getJavaPropertyFile().store( fos, '' );
		fos.close();
		
		return this;
	}

	/**
	* get
	*/
	function get( required string name, string defaultValue ){
		if( structKeyExists( arguments, 'defaultValue' ) ) {
			return getJavaPropertyFile().getProperty( name, defaultValue );			
		} else if( exists( name ) ) {
			return getJavaPropertyFile().getProperty( name );
		} else {
			throw 'Key [#name#] does not exist in this properties file';
		}
	}

	/**
	* set
	*/
	function set( required string name, required string value ){
		getJavaPropertyFile().setProperty( name, value );
		
		var syncedNames = getSyncedNames();
		this[ name ] = value;
		if( !arrayContains( syncedNames, name ) ){
			syncedNames.append( name );
		}
		setSyncedNames( syncedNames );
		
		return this;
	}

	/**
	* clear
	*/
	function remove( required string name ){
		if( exists( name ) ) {
			getJavaPropertyFile().remove( name );
			
			var syncedNames = getSyncedNames();
			if( arrayFind( syncedNames, name ) ){
				syncedNames.deleteAt( arrayFind( syncedNames, name ) );
			}
			setSyncedNames( syncedNames );
			structDelete( this, name );
		}
		return this;
	}

	/**
	* exists
	*/
	function exists( required string name ){
		return getJavaPropertyFile().containsKey( name );
	}

	/**
	* getAsStruct
	*/
	function getAsStruct(){
		syncProperties();
		var result = {};
		structAppend( result, getJavaPropertyFile() );
		return result;
	}
	
	/**
	* Keeps public properties in sync with Java object
	*/
	private function syncProperties() {
		var syncedNames = getSyncedNames();
		var ignore = listToArray( 'init,load,store,get,set,exists,remove,exists,getAsStruct,$mixed' );
		var propertyFile = getJavaPropertyFile();
				
		// This CFC's public properties
		for( var prop in this ) {
			// Set any new/updated properties in, excluding actual methods and non-simple values
			if( !ignore.findNoCase( prop ) && isSimpleValue( this[ prop ] ) ) {
				set( prop, this[ prop ] );
			}
		}
		
		// All the properties in the Java object
		var props = propertyFile.propertyNames();
		while( props.hasMoreElements() ) {
			var prop = props.nextElement();
			// Remove any properties that were deleted off the CFC's public scope
			if( !structKeyExists( this, prop ) ) {
				remove( prop );
			}
		}
		
	}

}