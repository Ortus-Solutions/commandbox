/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I execute cfm templates in isolation
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
	*/
	function run( required template ){
		savecontent variable="local.out"{
			include "#arguments.template#";
		}
		return local.out;
	}

}