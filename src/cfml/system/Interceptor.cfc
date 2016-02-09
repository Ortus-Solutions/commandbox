/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
* The base class for all CommandBox interceptors
*/
component accessors="true"{

	// Shell reference
	property name="shell";
	// LogBox reference
	property name="logBox";
	// Pre-Configured Log Object
	property name="log";
	// WireBox Reference
	property name="wirebox";
	// The interceptor properties structure
	property name="properties" 			type="struct";
	// The interceptor service
	property name="interceptorService" 	type="commandbox.system.services.InterceptorService";

	/**
	* Constructor
	* @shell.hint The CommandBox Shell
	* @properties.hint The properties to init the Interceptor with
	*
	* @result Interceptor
	*/
	function init( required shell, struct properties={} ){
		// Register Shell
		setShell( arguments.shell );
		// Register LogBox
		setLogBox( arguments.shell.getLogBox() );
		// Register Log object
		setLog( getLogBox().getLogger( this ) );
		// Register WireBox
		setWireBox( arguments.shell.getWireBox() );
		// store properties
		setProperties( arguments.properties );
		// setup interceptor service
		setInterceptorService( arguments.shell.getInterceptorService() );

		return this;
	}

	/**
	* Configuration method for the interceptor
	*/
	void function configure(){}

	/**
	* Get an interceptor property
	* @property.hint The property to retrieve
	* @defaultValue.hint The default value to return if property does not exist
	*/
	any function getProperty( required property, defaultValue ){
		return ( structKeyExists( variables.properties, arguments.property ) ? variables.properties[ arguments.property ] : arguments.defaultValue );
	}

	/**
	* Store an interceptor property
	* @property.hint The property to store
	* @value.hint The value to store
	*
	* @return Interceptor instance
	*/
	any function setProperty( required property, required value ){
		variables.properties[ arguments.property ] = arguments.value;
		return this;
	}

	/**
	* Verify an interceptor property
	* @property.hint The property to check
	*/
	boolean function propertyExists( required property ){
		return structKeyExists( variables.properties, arguments.property );
	}

	/**
	* Unregister the interceptor
	* @state.hint The named state to unregister this interceptor from
	*
	* @return Interceptor
	*/
	function unregister( required state ){
		var interceptorClass = listLast( getMetadata( this ).name, "." );
		getInterceptorService().unregister( interceptorClass, arguments.state );
		return this;
	}

}