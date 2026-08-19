/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I extend the abstract session factory class for jGit.
*/
package com.ortussolutions.commandbox.jgit;

import org.eclipse.jgit.transport.sshd.SshdSessionFactory;

public class GenericSessionFactory extends SshdSessionFactory {

       /**
        * Construct a session factory using the Apache MINA implementation.
        * The default configuration matches the previous JSCH behavior of JGit.
        */
       public GenericSessionFactory() {
               super();
       }


}
