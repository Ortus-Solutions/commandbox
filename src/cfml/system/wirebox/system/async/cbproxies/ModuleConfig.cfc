/**
 * Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
 * www.ortussolutions.com
 * ---
 * Core Java proxies for creating dynamic proxies to the SDK
 */
component {

	// Module Properties
	this.title       = "cbproxies";
	this.author      = "Ortus Solutions";
	this.webURL      = "https://www.ortussolutions.com";
	this.description = "This module allows CFML apps to create dynamic proxies to core Java interfaces and preserve its environment when ran asynchronously.";
	this.version     = "1.8.0+9";

	// Model Namespace
	this.modelNamespace = "cbproxies";

	// CF Mapping
	this.cfmapping = "cbproxies";

	// Dependencies
	this.dependencies = [];

	/**
	 * Configure Module
	 */
	function configure(){
	}

	/**
	 * Fired when the module is registered and activated.
	 */
	function onLoad(){
	}

	/**
	 * Fired when the module is unregistered and unloaded
	 */
	function onUnload(){
	}

}
