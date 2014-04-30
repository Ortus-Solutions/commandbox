/**
* I am the base command implementation-
**/
component {
	
	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		cr = chr(10);
		result = '';
		return this;
	}
	
	function run() {
		return 'This command CFC has not implemented a run() method.';
	}
	
	// Called prior to each execution to reset any state stored in the CFC
	function reset() {
		result = '';
	}
		
	// Get the result.  This will be called if the run() method doesn't return anything
	function getResult() {
		return result;
	}
	
	
	
}