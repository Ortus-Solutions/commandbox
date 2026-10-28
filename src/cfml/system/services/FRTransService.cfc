/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* FusionReactor Transaction Service.  I abstract interactions with the FRAPI, which may or may not exist.
* When the FR JVM args have been loaded in the JVM, I help assist in tracking custom transactions.
* If FR is not present, I do nothing.
*
*/
component accessors=true singleton {

	property name='FREnabled' type='boolean' default='false';
	property name='FRAPI';

	/**
	* The constructor detects if FR is present and stores a flag that can short circuit all the methods in this service if FR isn't running
	*/
	function init() {

		try{
			FrapiClass = createObject("java","com.intergral.fusionreactor.api.FRAPI");
			// FR loads async, wait for it to be done.
			while( isNull( FrapiClass.getInstance() ) || !FrapiClass.getInstance().isInitialized() ) {
				sleep( 500 );
			}
			setFRAPI( FrapiClass.getInstance() );
			setFREnabled( true );
		} catch( any e ) {
			// If FR isn't present, this will hit the catch and this entire service will be "disabled"
			setFREnabled( false );
		}

    	return this;
	}

	/**
	* Start a named transaction in FR.  This transaction will stay "running" in FR until endTransaction() is called.
	*
	* @name The short name of the transaction
	* @description Full details of this transaction
	*/
	function startTransaction( required string name, string description='' ) {
		if( !getFREnabled() ) {
			return {};
		}

		var FRTransaction = getFRAPI().createTrackedTransaction( name );
		getFRAPI().setTransactionApplicationName( getApplicationMEtadata().name ?: 'CommandBox CLI' );
		FRTransaction.setDescription( description );
		return FRTransaction;
	}

	/**
	* Will close a transaction by reference
	*
	* @FRTransaction Instance of FR Transaction object, returned by previous call to startTransaction.
	*/
	function endTransaction( required FRTransaction ) {
		if( !getFREnabled() ) {
			return;
		}
		FRTransaction.close();
	}

	/**
	* Mark a transaction as having an error.  This will NOT end the transaction.  You must still do that.
	*
	* @FRTransaction Instance of FR Transaction object, returned by previous call to startTransaction.
	* @javaException Instance of Java exception object that represents the error
	*/
	function errorTransaction( required FRTransaction, required javaException ) {
		if( !getFREnabled() ) {
			return;
		}
		FRTransaction.setTrappedThrowable( javaException );
	}


}
