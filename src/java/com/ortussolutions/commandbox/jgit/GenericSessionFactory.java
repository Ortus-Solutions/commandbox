package com.ortussolutions.commandbox.jgit;

import org.eclipse.jgit.transport.JschConfigSessionFactory;
import org.eclipse.jgit.transport.OpenSshConfig;
import com.jcraft.jsch.Session;

public class GenericSessionFactory extends JschConfigSessionFactory {

	@Override
	protected void configure( OpenSshConfig.Host host, Session session ) {
		// This prevents users from having the host in "~/.ssh/known_hosts"
		java.util.Properties config = new java.util.Properties(); 
		config.put("StrictHostKeyChecking", "no");
		session.setConfig( config );
	}

	
}
