/**
 * Debugs what env vars are loaded in what environemnts
 * .
 * {code:bash}
 * env debug
 * {code}
   **/
component  {

	/**
	* 
	*/
	function run()  {
		print.line( systemSettings.getAllEnvironments() );
	}

}
