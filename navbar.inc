<!-- navbar.inc
	This file exists soley for the purpose of the drawing the nav bar at the top
	of the webpage when it loads.
-->

<?php

require 'counter.inc';

$navnames = array("Home", "Tech Stuff", "History", "Links", "About");
$navlinks = array("index.php", "tech.php", "history.php", "links.php", "about.php");


function do_navbar() {
?>
<!-- First make a seperate table for the counter -->
<table width=100% >
  <tbody>
    <tr>
      <td width=80%> <?php do_realnavbar(); ?>  </td>
      <td  align="center" width=20%> <?php print_hits(); ?> </td>
    </tr>
  </tbody>
</table>

<?php
}

// do_navbar really just draws the stuff around the nav bar. This is where the actual navbar gets
// drawn.
function do_realnavbar() {
	?>
		<table width=100% height=100% bgcolor="Lime" cellspacing="3" cellpadding="3" >
		 <tbody>
		  <tr align="baseline">
	<?php
		global $navnames, $navlinks;
		// Go through and print out each header
		$i = 0;
		foreach($navnames as $name) {
			echo "<td bgcolor=\"Black\" align=\"center\"> <a href=\"$navlinks[$i]\">$name</a> </td>";
			$i++;
		}
	?>
		  </tr>
		 </tbody>
		</table>
	<?php
}

?>
