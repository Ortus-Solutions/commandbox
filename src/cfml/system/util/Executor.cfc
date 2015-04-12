/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I execute cfm templates in isolation
* Do not make this a singleton or cache it unless you
* want to persist its state between executions.  That is because
* the "variables" scope is retained between calls to the "run()" method.
*/
component {
	
	/**
	* Constructor
	*/
	function init(){
		return this;
	}

	/**
	* Execute
	* @template.hint path to a .cfm to execute
	* @vars.hint Struct of vars to set so the template can access them
	*/
	function run( required template, struct vars = {} ){
		
		// Mix the incoming vars into the "variables" scope.
		structAppend( variables, vars );
				
		savecontent variable="local.out"{
			include "#arguments.template#";
		}
		return local.out;
	}
	
	/**
	* eval
	* @statement.hint A CFML statement to evaluate
	*/
	function eval( required string statement ){
		return evaluate( arguments.statement );
	}


}