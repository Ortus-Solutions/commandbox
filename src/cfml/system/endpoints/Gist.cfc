/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the gist endpoint
*
* - gist:<gistID>
* - gist:<gistID>#<commit-ish>
* - gist:<githubname>/<gistID>
* - gist:<githubname>/<gistID>#<commit-ish>
*
* If no <commit-ish> is specified, then master is used.
*
*/
component accessors=true implements="IEndpoint" extends="commandbox.system.endpoints.Git" singleton {

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'gist' );
		return this;
	}

	private function getProtocol() {
		return 'https://gist.github.com/';
	}

}
