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

import org.eclipse.jgit.api.TransportConfigCallback;
import org.eclipse.jgit.transport.*;
import com.ortussolutions.commandbox.jgit.GenericSessionFactory;

public class SSHCallback implements TransportConfigCallback {

	public void configure(Transport transport) {

		JschConfigSessionFactory genericSessionFactory = new GenericSessionFactory();
		
		SshTransport sshTransport = ( SshTransport )transport;
		sshTransport.setSshSessionFactory( genericSessionFactory );

	}
}
