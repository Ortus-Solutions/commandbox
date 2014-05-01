/**
* Command hint
**/
component extends="cli.BaseCommand" aliases='test,foobar' {
	
	/**
	* @doo.hint This is the doo, you know.
	**/
	function run( foo, bar, required doo ) {
		return structKeyList( arguments );
	}
	
	// Help method
	function help() {
		
	}
	
}