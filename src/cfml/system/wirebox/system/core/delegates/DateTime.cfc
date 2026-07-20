/**
 * This delegate is useful to interact with the wirebox.system.async.time.DateTimeHelper as your date time helper
 */
component singleton {

	property
		name  ="dateTimeHelper"
		inject="wirebox.system.async.time.DateTimeHelper"
		delegate;

}
