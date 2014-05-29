/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle artifacts, which are basically just a cache of downloaded libraries.
*
*/
component singleton {
	
	property name='artifactDir' inject='artifactDir';
	
	// list artifacts (optionally by slug)
	
	// clear artifacts (all, by slug, or by slug and version)
	
	// artifact exists? (any version, specific version)
	
	// get artifact location
	
	// create artifact (Should this take care of downloading, or be passed a temp directory of an already downloaded item?)
	
	// install artifact
	
	
}