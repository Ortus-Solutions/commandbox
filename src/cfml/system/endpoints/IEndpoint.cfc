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

	/**
	* Checks to see if there is an update to the package
	* @returns a struct specifying if the currently installed version
	* is outdated as well as the newly available version.
	* The default return struct is this:
	*
	* {
	* 	isOutdated = false,
	* 	version = ''
	* }
	*
	* @throws endpointException
	*/
	public function getUpdate( required string package, required string version, boolean verbose=false );

}