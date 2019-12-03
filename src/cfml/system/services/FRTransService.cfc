/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* FusionReactor Transaction Service
*
*/
component accessors=true singleton {

	property name='FREnabled' type='boolean' default='false';
	property name='FRAPI';

	function init() {
		
		try{ 
			FrapiClass = createObject("java","com.intergral.fusionreactor.api.FRAPI");
			while( isNull( FrapiClass.getInstance() ) || !FrapiClass.getInstance().isInitialized() ) {
				sleep( 500 );
			}			setFRAPI( FrapiClass.getInstance() );
			setFREnabled( true );
		} catch( any e ) {
			setFREnabled( false );	
		}
		
    	return this;
	}
	
	function startTransaction( required string name, string description='' ) {
		if( !getFREnabled() ) {
			return {};
		}
		
		var FRTransaction = getFRAPI().createTrackedTransaction( name );
		getFRAPI().setTransactionApplicationName( getApplicationMEtadata().name ?: 'CommandBox CLI' );
		FRTransaction.setDescription( description );
		return FRTransaction;
	}
	
	function endTransaction( required FRTransaction ) {
		if( !getFREnabled() ) {
			return;
		}
		FRTransaction.close();
	}
	
	function errorTransaction( required FRTransaction, required javaException ) {
		if( !getFREnabled() ) {
			return;
		}
		FRTransaction.setTrappedThrowable( javaException );
	}
	
	
}
