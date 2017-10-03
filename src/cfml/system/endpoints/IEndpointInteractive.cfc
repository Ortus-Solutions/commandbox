/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am an interactive endpoint.  That means I can not only resolve packages,
* but be logged into and can have packages published to me.
*/
interface extends="IEndpoint" {

	// Returns access token
	public string function createUser(
		required string username,
		required string password,
		required string email,
		required string firstName,
		required string lastName );

	// Returns access token
	public string function login( required string userName, required string password );

	public function publish( required string path, string zipPath, boolean forceUpload );

	public function unpublish( required string path, string version='' );

}
