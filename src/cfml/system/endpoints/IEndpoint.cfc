/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am an endpoint.  I can retreive packages for you.
*/
interface {
	
	/**
	* Accepts the name of a package, retrieves it, and returns a local folder path where the package is
	* 
	* @throws endpointException
	*/
	public string function resolvePackage( required string package, boolean verbose=false );

	/**
	* Determines the name of a package based on its ID if there is no box.json
	*/
	public function getDefaultName( required string package );

}