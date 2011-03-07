<!-- counter.inc. This handles all the stuff for connecting to a mysql db and
  doing the counting etc.

-->
<?php

//define ("HOSTNAME", "mysql.sourceforge.net");
define ("HOSTNAME", "bif");
define ("USERNAME", "bif");
define ("PASSWORD", "hide");
define ("DB","bif");

$db_handle = 0;

// Table_name is the script name minus the .php and ./ at the begining
$table_name = substr($PHP_SELF, 1);
$table_name = substr($table_name, 0, strlen($table_name) - 4);
// Add a _ on all names so they won't conflict with anything
$table_name = $table_name . "_accesslog";


// Connect to the database.
function connect_to_db() {
	global $db_handle;
	$db_handle = mysql_connect(HOSTNAME, USERNAME,PASSWORD);
	if(!mysql_select_db(DB, $db_handle)) {
		echo "Failed to open database ";
		echo DB;
	}
	// Should be set up and queries should be going to our db now
}

function close_db()
{
	global $db_handle;
	mysql_close($db_handle);
}

// Add the entry for this hit
function add_entry() {
	global $db_handle, $table_name, $HTTP_USER_AGENT, $REMOTE_ADDR;

	// We have to mash down the IP_ADDR string into an integer value
	$IP = (intval($REMOTE_ADDR) << 24);
	$STRPAR = substr(strstr($REMOTE_ADDR, "."), 1);
	$IP = $IP + (intval($STRPAR) << 16);
	$STRPAR = substr(strstr($STRPAR, "."), 1);
	$IP = $IP + (intval($STRPAR) << 8);
	$STRPAR = substr(strstr($STRPAR, "."), 1);
	$IP = $IP + (intval($STRPAR));
	$IPSTR =  sprintf ("%u", $IP);
	//echo "INSERT INTO $table_name VALUES ($IPSTR, \"$HTTP_USER_AGENT\", NULL)";
	return mysql_query("INSERT INTO $table_name VALUES ($IPSTR, \"$HTTP_USER_AGENT\", NULL)", $db_handle);
}

// This function adds an entry to the db for this page
function add_hit()
{
	global $db_handle, $PHP_SELF, $table_name;


	// First try adding the entry
	if(!add_entry($table_name)) {
		// It's possible this is the first time this page has been acessed
		// Try creating a new table.

		if(mysql_query("CREATE TABLE $table_name (ipaddr INT UNSIGNED NOT NULL, useragent TINYTEXT NOT NULL, hittime TIMESTAMP NOT NULL)",
			$db_handle)) {
			// Try once more
			add_entry($table_name);
		}
		else
			print "Failed trying to add table";
	}
}

function count_hits()
{
	global $db_handle, $table_name;
	$result = mysql_query("SELECT COUNT(*) FROM $table_name", $db_handle)
		or die ("Failed to count table");
	$hits = mysql_result($result, 0);
	mysql_free_result($result);
	return $hits;
}

function print_hits() {
	connect_to_db();
	add_hit();
	$hits = count_hits();
	if($hits < 2)
		print "Congratulations! You are the first hit for this page";
	else
		print "There have been $hits hits on this page";

	close_db();
}

?>
