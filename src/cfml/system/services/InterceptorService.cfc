/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
* The InterceptorService that wraps the EventPoolManager and provides special treatment
* for interceptors to give them virtual inheritance and autowiring
*/
component accessors=true singleton {
	property name='Shell';
	property name='EventPoolManager';
	property name='InterceptionPoints';
	
	// DI
	property name='log' inject='logbox:logger:{this}';

	/**
	* @shell.inject shell
	
	*/
	InterceptorService function init( required shell ) {
		setShell( arguments.shell );

		setInterceptionPoints( [
			// CLI lifecycle
			'onCLIStart','onCLIExit',
			// Command execution lifecycle
			'preCommand','postCommand',
			// Module lifecycle
			'preModuleLoad','postModuleLoad','preModuleUnLoad','postModuleUnload',
			// Server lifecycle
			'onServerStart','onServerInstall','onServerStop',
			// Error handling
			'onException',
			// Package lifecycle
			'preInstall','postInstall','preUninstall','postUninstall','preVersion','postVersion','prePublish','postPublish','preUnpublish','postUnpublish'		
		] );
				
		return this;
	}


	function configure() {
		setEventPoolManager( getShell().getWireBox().getEventManager() );
		appendInterceptionPoints( getInterceptionPoints().toList() );
		return this;		
	}
 
	function announceInterception( required string state, struct interceptData={} ) {
		getEventPoolManager().processState( state, interceptData );
	}
	
	/**
	* @interceptor.hint The qualified class of the interceptor to register or an already instantiated object as an interceptor.
	* @interceptorProperties.hint The structure of properties to register this interceptor with.
	* @interceptorProperties.colddoc:generic struct
	* @customPoints.hint A comma delimmited list or array of custom interception points, if the object or class sent in observes them.
	* @interceptorName.hint The name to use for the interceptor when stored. If not used, we will use the name found in the object's class
	*/
	function registerInterceptor(
		any interceptor,
		struct interceptorProperties={},
		string customPoints='',
		string interceptorName=''
	) {
	
		// determine registration names
		if( !len( arguments.interceptorName ) ) {
			if( isSimpleValue( arguments.interceptor ) ){
				arguments.interceptorName = listLast( arguments.interceptor, "." );
			} else {
				arguments.interceptorName = listLast( getMetaData( arguments.interceptor ).name, ".");
			}
		}

		// Did we send in a class to instantiate
		if( isSimpleValue( arguments.interceptor ) ) {
			// Create the Interceptor Class
			try{
				arguments.interceptor = createInterceptor( arguments.interceptor, arguments.interceptorName, arguments.interceptorProperties );
			}
			catch(Any e){
				log.error("Error creating interceptor: #arguments.interceptor#. #e.message# #e.detail# #e.stackTrace#",e.tagContext);
				rethrow;
			}

			// Configure the Interceptor
			arguments.interceptor.configure();

		}//end if class is sent.

		getEventPoolManager().register( arguments.interceptor, arguments.interceptorName, arguments.customPoints );

		return this;
	}

	/**
	* @interceptorClass.hint The class path to instantiate
	* @interceptorName.hint The unique name of the interceptor
	* @interceptorProperties.hint The properties
	*/
    function createInterceptor(
    	required string interceptorClass,
		interceptorName,
		interceptorProperties={}
    ) {
		var oInterceptor = "";
		var wirebox = getShell().getWireBox();

		// Check if interceptor mapped?
		if( NOT wirebox.getBinder().mappingExists( "interceptor-" & interceptorName ) ){
			// wirebox lazy load checks
			wireboxSetup();
			// feed this interceptor to wirebox with virtual inheritance just in case, use registerNewInstance so its thread safe
			wirebox.registerNewInstance(name="interceptor-" & interceptorName, instancePath=interceptorClass)
				.setScope( wirebox.getBinder().SCOPES.SINGLETON )
				.setThreadSafe( true )
				.setVirtualInheritance( "commandbox.system.Interceptor" )
				.addDIConstructorArgument( name="shell", value=getShell() )
				.addDIConstructorArgument( name="properties", value=interceptorProperties );
		}
		// retrieve, build and wire from wirebox
		oInterceptor = wirebox.getInstance( "interceptor-" & interceptorName );
		// check for virtual $super, if it does, pass new properties
		if( structKeyExists(oInterceptor, "$super") ){
			oInterceptor.$super.setProperties( interceptorProperties );
		}

		return oInterceptor;
	}
    
    /**
    * Verifies the setup for interceptor classes is online
    */
    private function wireboxSetup() {
		var wirebox = getShell().getWireBox();

		// Check if handler mapped?
		if( NOT wirebox.getBinder().mappingExists( 'commandbox.system.Interceptor' ) ){
			// feed the base class
			wirebox.registerNewInstance(name='commandbox.system.Interceptor', instancePath='commandbox.system.Interceptor')
				.addDIConstructorArgument( name="shell", value=getShell() )
				.addDIConstructorArgument( name="properties", value=structNew() )
				.setAutowire( false );
		}
    }
    
    /**
    * Get an interceptor according to its name from a state. 
    */
	function getInterceptor( required string interceptorName ) {
		return getEventPoolManager().getObject( arguments.interceptorName );
	}

	/**
	* Append a list of custom interception points to the CORE interception points and returns itself
	* @customPoints.hint A comma delimmited list or array of custom interception points to append. If they already exists, then they will not be added again.
	*/
	function appendInterceptionPoints( required customPoints='' ) {
		getEventPoolManager().appendInterceptionPoints( customPoints );
		return this;
	}

	/**
	* Get the registered event states in this event manager
	*/
	function getInterceptionStates() {
		return getEventPoolManager().getEventStates();
	}

	/**
	* Unregister an interceptor from an interception state or all states. If the state does not exists, it returns false
	*/
	function unregister( required string name, state='' ) {
		return getEventPoolManager().unregister( arguemnts.name, arguments.state );
	}

}