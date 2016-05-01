/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I implement the SSH callback class for jGit to support SSH
*/
package com.ortussolutions.commandbox.jgit;

import org.eclipse.jgit.api.GitCommand;
import java.lang.Exception;

public class CommandCaller {

	private Throwable exception; 

	public Object call( GitCommand command ) throws Exception {

		try { 
			return command.call();
		} catch( Throwable e ) {
			this.exception = e;
			throw new Exception( "Error calling command.", e );
		}
	}
	
	public Throwable getException() {
		return this.exception;
	}
}
