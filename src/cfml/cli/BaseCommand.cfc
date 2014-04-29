/**
* I am the base command implementation-
**/
component {
	
	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		cr = chr(10);
		return this;
	}
	
	function run() {
		return 'This command CFC has not implemented a run() method.';
	}
	
	
	
}