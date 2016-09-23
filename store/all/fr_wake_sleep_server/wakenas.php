<?php

 // Port wake on lan
$socket_number = "9";
// Adresse Mac du Serveur à allumer
$mac_addy = "00:18:99:A1:9B:A1";
// On lance le packet magique sur l'adresse de broadcast'
$ip_addy = gethostbyname("192.168.0.255");


function WakeOnLan($addr, $mac,$socket_number) {
  $addr_byte = explode(':', $mac);
  $hw_addr = '';
  for ($a=0; $a <6; $a++) $hw_addr .= chr(hexdec($addr_byte[$a]));
  $msg = chr(255).chr(255).chr(255).chr(255).chr(255).chr(255);
  for ($a = 1; $a <= 16; $a++) $msg .= $hw_addr;

  // send it to the broadcast address using UDP
  $s = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);

  if ($s == false) {
    return FALSE;
    } else {
    // Broadcast option
    $opt_ret = socket_set_option($s, 1, 6, TRUE);

    if($opt_ret <0) {
      return FALSE;
      }
    if(socket_sendto($s, $msg, strlen($msg), 0, $addr, $socket_number)) {
      socket_close($s);
      return TRUE;
      } else {
      return FALSE;
      }
    }
  }

                  

//On regarde si le serveur est en ligne ou non
$alive = fsockopen($ip_addy, 80, $errno, $errstr, 2);   

    if (!$alive) {
        ;

        //On lance le wake on lan si il est éteint
        WakeOnLan($ip_addy, $mac_addy,$socket_number);

    } else {
      
        fclose($alive);
    }
	

?>

