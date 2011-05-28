GCPing -- Apple Game Center Test Application
============================================

Test matchmaking and multiplayer via Apple's GameKit APIs.

Requires Game Center compatible devices (OS 4.1+).

Warning
-------

* Peer-to-Peer networking of mobile devices is very flaky
  * Sessions may start but opponents may not connect
  * Data may be sent one direction, but not be received by the other

GCPing only exposes the problems and cannot solve the fundamental issues with NATs and Firewalls.

Interesting features
--------------------

* Multiplayer Matchmaking with Voice Chat (2-4 players)
* Add more players (up to 4) into an existing session
* Send reliable "ping" command to other devices and get back RTT

Brought to you by [Damon Danieli][2] at [Z2Live, Inc.][1]

[1]: http://www.z2live.com
[2]: http://damondanieli.blogspot.com

<!--
vi: filetype=mkd
-->
