<?php

// index.php

require ('common.inc');

common_start("Welcome to the Bif Site");

?>

<!--- Table for two animated gifs and the latest news ---->
<table>
  <tbody>
	<tr>
	  <td>
		  <img src="animated_robot.gif" alt="Picture of Robot Side On" width=250 height=126 border=0>
		</td>
		<td>
		  <div align="center">
			  <h2>
		      Latest News
				</h2>
			</div>
		  <?php
			  // Import the news
        readfile("projnews.cache");
			?>
		</td>
		<td>
		  <img src="robot_spinning.gif" alt="Picture of robot from above" width=230 height=179 border=0>
		</td>
	</tr>
	</tbody>
</table>

<br>

<!--- General info about site etc. --->


<div align="center">
  <h1>
    Welcome to the online headquarters of Project Bif
		<br>
  </h1>
	If you have absolutely no clue what "Project Bif" is I'd suggest you click on the back button
	or you could look at
	<a href="about.php">
	  what this site is all about.
	</a>
	<br>
	<br>
  If you do know what "Project Bif" is, there is a high probability that you are insane.
	I'd suggest you
	<a href="http://www.drgoschi.com">
	  consult a pyschologist.
	</a>
	<br>
	<br>
  If you are after some useful stuff that was used to helped build the robot check out the
	<a href="links.php">
	  links page.
	</a>
  For more about the history of Project Bif look at the
	<a href="history.php">
	  history</a>
	 (duh).
	<br>
	<br>
	And last but not least if you want to find out more about how bif works look at the
	<a href="tech.php">
	  tech page.</a>
  <font color="Red">
	  Warning: This page may contain complex details and descriptions that could be damaging to
		your mental health.
	</font>
	<br>
	<br>
	Lastly, if you're looking for links to the sourceforge development stuff (which probably means
	you are one of the people working on the robot and are definitely insane) look
	<a href="#sflinks">
	below</a>
  <br>
	<br>
	<br>
	<br>
	<br>
</div>
<hr>

<!--- Links to the sourceforge stuff ---->
<a name = "sflinks">
  <table>
	  <caption>
		  <b> Sourceforge Links - <font color="Red"> Authorized Personnel Only </font> </b>
		</caption>
    <tbody>
      <tr>
        <td>
          <?php
            readfile("projhtml.cache");
          ?>
        </td>
      </tr>
  </tbody>
  </table>
</a>

<?php

common_end("\$id$");

?>


