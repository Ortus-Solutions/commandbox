/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* This class is a java wrapper to call JGit commands and trap the FULL exceptions
* that might be thrown to work around a Lucee bug that discards the "cause" of 
* exceptions.  Create an instance of this class to call a JGit command and if it 
* throws an exception, if your CFML catch, use getException() to get the real error
*/
package com.ortussolutions.commandbox.jgit;

import org.eclipse.jgit.api.GitCommand;
import java.lang.Exception;

public class CommandCaller {

	private Throwable exception; 

	/**
	 * Use this method to call a Jgit command for you and capture any exceptions that are thrown.
	 * 
	 * @param command The Jgit  object to call
	 * @return Whatever results that come back from the Jgit command's calling
	 * @throws Exception
	 */
	public Object call( Callable command ) throws Exception {

		try { 
			
			// Try to run the command
			return command.call();
			
		// if it errors
		} catch( Throwable e ) {
			
			// Store the exception
			this.exception = e;
			// And rethrow.  Lucee 4.x will strip off the cause.
			throw new Exception( "Error calling command.", e );
			
		}
	}
	
	/**
	 * If an exception is thrown from the call() method, this will return the original Java exception
	 * Otherwise, this will return null.
	 * @return Original java exception from the Jgit command, if it errored.
	 */
	public Throwable getException() {
		return this.exception;
	}
}
