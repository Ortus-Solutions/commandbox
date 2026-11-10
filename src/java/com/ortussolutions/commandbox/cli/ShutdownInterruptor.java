/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
*
* Best-effort JVM shutdown hook.  Interrupts the recorded main thread so CommandBox can
* stop anything it started (such as a server) before the JVM exits.
*
* Used by the CommandBox CLI when running directly on BoxLang (box.bat -> boxlang.bat),
* where there is no Java bootstrap to register this for us.
*
* I am implemented in Java on purpose.  A shutdown hook runs after the BoxLang runtime
* has been torn down, so a BoxLang-implemented Runnable has to bootstrap a brand new
* runtime with default settings just to execute its own body.  Staying in pure Java
* keeps BoxLang out of the shutdown path entirely.
*/
package com.ortussolutions.commandbox.cli;

public class ShutdownInterruptor implements Runnable {

	/** Roughly 10 seconds, matching the grace period of the Java bootstrap hook. */
	private static final int MAX_CHECKS = 100;
	private static final long SLEEP_MILLIS = 100;

	private final Thread mainThread;
	private final boolean debugEnabled;

	public ShutdownInterruptor(Thread mainThread, boolean debug) {
		this.mainThread = mainThread;
		this.debugEnabled = debug;
		debug("CommandBox shutdown hook registered; it will interrupt the main thread when the process is asked to stop");
	}

	/**
	 * Called by the JVM on shutdown.
	 */
	@Override
	public void run() {
		debug("Process is shutting down; interrupting the main thread so CommandBox can clean up");
		try {
			debug("Interrupting the main thread, state=" + mainThread.getState());
			mainThread.interrupt();

			// If main is already parked in the JVM's shutdown-hook sequence waiting on this
			// hook, it can never finish while we run, so waiting on it just burns the whole
			// grace period.  Bail out immediately in that case.
			if (mainIsParked()) {
				debug("Main thread already parked in the shutdown sequence; not waiting on it");
				return;
			}

			long startedAt = System.currentTimeMillis();
			int i = 0;
			// Give main a short grace period to finish its own cleanup (i.e. stop the server)
			// before the JVM halts, sleeping between checks so we don't spin the CPU.
			for (; mainThread.isAlive() && i < MAX_CHECKS; i++) {
				// Main can park mid-wait: it finishes unwinding and then calls System.exit(),
				// which blocks because a signal handler already owns the shutdown sequence.
				if (mainIsParked()) {
					debug("Main thread parked after " + (System.currentTimeMillis() - startedAt)
							+ "ms; not waiting on it");
					return;
				}
				try {
					Thread.sleep(SLEEP_MILLIS);
				} catch (InterruptedException e) {
					debug("Shutdown hook was interrupted; giving up on the main thread");
					break;
				}
			}

			debug(mainThread.isAlive()
					? "Main thread still running after " + (System.currentTimeMillis() - startedAt)
							+ "ms; giving up so the JVM can exit"
					: "Main thread exited after " + (System.currentTimeMillis() - startedAt)
							+ "ms; cleanup is done");
		} catch (Throwable e) {
			// Nothing useful to do while the JVM is going away
			debug("Unexpected error while waiting on the main thread: " + e);
		}
	}

	/**
	 * Is main parked somewhere it can no longer make progress from?
	 *
	 * Either it is inside ApplicationShutdownHooks.runHooks() joining this very hook, or it is
	 * parked in java.lang.Shutdown.exit() because another thread (a SIGINT/SIGTERM handler)
	 * already owns the shutdown sequence and holds the Shutdown class monitor forever.  In
	 * both cases waiting on main just burns the whole grace period.
	 *
	 * Checking for the Shutdown frames rather than just Thread.State.BLOCKED keeps this from
	 * tripping on ordinary lock contention somewhere in main's own work.
	 */
	private boolean mainIsParked() {
		for (StackTraceElement frame : mainThread.getStackTrace()) {
			String className = frame.getClassName();

			if (className.contains("ApplicationShutdownHooks")) {
				debug("Main thread is joining the JVM shutdown hooks, state=" + mainThread.getState());
				return true;
			}
			if (className.equals("java.lang.Shutdown")) {
				debug("Main thread is parked in Shutdown." + frame.getMethodName() + ", state=" + mainThread.getState());
				return true;
			}
		}

		return false;
	}

	/**
	 * Only noisy when the CLI was started with -clidebug.
	 */
	private void debug(String message) {
		if (debugEnabled) {
			System.out.println("[clidebug] " + message);
		}
	}

}
