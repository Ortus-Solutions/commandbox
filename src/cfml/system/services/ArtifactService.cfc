/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle artifacts, which are basically just a cache of downloaded packages.
*
*/
component singleton {
	
	property name='artifactDir' inject='artifactDir';
	
	function onDIComplete() {
		
		// Create the artifacts directory if it doesn't exist
		if( !directoryExists( artifactDir ) ) {
			directoryCreate( artifactDir );
		}
		
	}
	
	/**
	* List the packages in the artifacts cache.
	* @slug.hint Supply a slug to see only versions of this package
	* @returns A struct of arrays where the struct key is the package slug and the array contains the versions of that package in the cache.
	*/
	function listArtifacts( slug='' ) {
		var result = {};
		var dirList = directoryList( path=artifactDir, recurse=false, listInfo='query', sort='name asc' );
		
		for( var dir in dirList ) {
			if( dir.type == 'dir' && ( !arguments.slug.len() || arguments.slug == dir.name ) ) {
				var verList = directoryList( path=dir.directory & '\' & dir.name, recurse=false, listInfo='query', sort='name asc' );
				// Ignore package dirs with no actual versions in them
				if( verList.recordCount ) {
					result[ dir.name ] = [];
				}
				for( var ver in verList ) {
					if( ver.type == 'dir' ) {
						result[ dir.name ].append( ver.name );
					}
				}
			}
		}
		
		return result;
		
	}
	
	// clean artifacts -- remove all 
	
	// remove artifacts (by slug, or by slug and version?)
	
	// artifact exists? (any version, specific version)
	
	// get artifact location (slug, version)
	
	// create artifact (Should this take care of downloading, or be passed a temp directory of an already downloaded item?)
	
	// install artifact
	
	
}