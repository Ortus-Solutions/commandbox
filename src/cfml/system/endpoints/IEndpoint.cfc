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
	* @throws endpointException
	*/
	public string function resolvePackage( required string package, boolean verbose=false );

}