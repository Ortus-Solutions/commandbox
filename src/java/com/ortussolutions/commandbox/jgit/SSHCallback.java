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
