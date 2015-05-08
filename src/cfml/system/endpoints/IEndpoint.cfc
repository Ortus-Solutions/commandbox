/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am an endpoint.  I can retreive packages for you.
*/
interface accessors="true" {
	property name="namePrefixs" type="string";
	
	public string function resolve( required string ID );

}