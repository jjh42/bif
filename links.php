<?php
// Links.php

// The links array is is formatted like this.
// Each group consists of an array with a name, link name (so that its possible to
// 	link to a group of links and an array of entries.
// Each array of entries is just an array or arrays containing two entries. A link and a description
// Follow what's already there for an example.
$links = array(
	array ("General", "general",
		array (
			array("http://www.google.com", "The world's best search engine - used more than once for looking for hard to find stuff."),
			array("http://sourceforge.net", "The people who give us free webhosting, CVS repository and more for nothing."),
		)
	),
	array ("Rabbit 2000", "r2k",
		array (
			array("http://www.rabbitsemiconductor.com", "The makers of the Rabbit 2000 microprocessor."),
		)
	),
	array ("AVR Links", "avrlinks",
		array (
			array("http://www.atmel.com", "Atmel is the maker of the AVR microprocessor."),
			array("http://www.gnu.org/software/binutils/", "GNU Binutils contains a linker and assembler for the AVR which is used by Project Bif."),
		)
	),
	array ("Editors", "editors",
		array (
			array("http://www.kdevelop.org", "KDevelop is used by one member of Project Bif for almost all his editing because it is really nice."),
		)
	),
	array ("Tools", "tools",
		array (
			array("http://www.gnu.org/software/gcc/gcc.html", "Homepage for the GCC compiler suite which is used for compiling code under linux for uploading to the robot and simulating parts of it."),
			array("http://www.cvshome.org", "The home of CVS which we use for safeguarding our code."),
			array("http://cervisia.sourceforge.net", "And a GUI tool for CVS."),
			array("http://www.wincvs.org", "And another CVS GUI for another OS."),
			array("http://www.gnu.org", "GNU makes too many utilities to list. Many of them are used one way or another in Project Bif."),
		)
	),
	array ("Operating Systems", "os",
		array (
			array("http://www.microsoft.com", "The maker of the one of the operating systems used for working on the robot."),
			array("http://www.linux.org", "The official site of the other one."),
			array("http://www.kde.org", "Not really an OS but the Desktop Environment of choice for one of us."),
			array("http://www.gnome.org", "And the Desktop Environment of choice for the other one."),
			array("http://www.redhat.com", "The homepage of one of distrubtions that was used for working on the robot"),
			array("http://www.mandrake.com", "The homepage of another."),
			array("http://www.gentoo.org", "And another."),
			array("http://www.debian.org", "And another."),
		)
	),
	array ("Web development", "webdev",
		array (
			array("http://quanta.sourceforge.net", "Quanta Plus is a lot more than an editor and was used for making this site."),
			array("http://www.mysql.com", "MySQL databases are used for parts of this site."),
			array("http://www.php.net", "PHP server side scripting is serving you this page."),
		)
	),
);


require ('common.inc');

common_start("Links used by Project Bif");

?>

<H1>Links</H1>
This page contains links to some of the sites that the Bif Project has used in one way or another
 to help build the robot. You might find some of them useful too. The links are divided into the
 following categories:

<?php

// First go through list and print out the headings
echo "<div align=\"center\">";
foreach ($links as $category) {
	echo "<h4><a href=\"#" . $category[1] . "\">" . $category[0] . "</a></h4>";
}
echo "</div><br><br>";

function do_section($section)
{
	list($name, $link, $items) = $section;
	echo "<a name=\"" . $link . "\"><H2>$name</H2>";
	echo "<ul>";
	foreach($items as $entry) {
		$url = $entry[0];
		$desc = $entry[1];
		echo "<li><a href=\"" . $url . "\"><b>$url</b></a> - $desc</li>";
	}
	echo "</a></ul><br><br>";
}

foreach ($links as $section)
{
	do_section($section);

}

common_end("\$id$");

?>

