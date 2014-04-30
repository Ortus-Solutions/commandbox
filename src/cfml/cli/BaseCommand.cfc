/**
* I am the base command implementation-
**/
component {
	
	cr = chr(10);
	print = new PrintBuffer();
	
	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		return this;
	}
	
	function run() {
		return 'This command CFC has not implemented a run() method.';
	}
	
	// Called prior to each execution to reset any state stored in the CFC
	function reset() {
		print.clear();
	}
		
	// Get the result.  This will be called if the run() method doesn't return anything
	function getResult() {
		return print.getResult();
	}
	
	
	
}