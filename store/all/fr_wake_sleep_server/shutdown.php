<?php

include_once('utils.php');

set_time_limit(5);
ini_set("display_errors",0);error_reporting(0);

$commande = 'poweroff';    // commande shell à envoyer à la machine cible.
 
// Etablissement de la connexion ssh2, port 22
if (false === $connection = ssh2_connect($hostname, 22)) {
  echo '<h1>Le serveur est éteint</h1><br />';
  exit();  // sortie si erreur
  }
else {
  echo 'connexion établie<br />';
  }
 

//authentification utilisateur
if (false === ssh2_auth_password($connection, $username, $password)) {
  echo 'Echec identification<br />';
  exit(); // sortie si erreur
  }
else {
  echo 'Identification réussie !<br />';
  }
 
//exécution command shell sur la machine destinataire
if (false === $stream = ssh2_exec($connection, $commande)) {
  echo "erreur d'exécution commande shell<br />";
  }
 
// sortie du résultat quand il y en a un
stream_set_blocking($stream, true);
$output = '';
while($ligne = fgets($stream)) {
  $output = $output . $ligne . '<br />';
  }
echo $output;
 
// Sortie de l'erreur quand il y en a une
$stderr = ssh2_fetch_stream($stream, SSH2_STREAM_STDERR);
stream_set_blocking($stderr, true);
$output = '';
while($ligne = fgets($stderr)) {
  $output = $output . $ligne . '<br />';
  }
echo $output;
fclose($stderr);
fclose($stream);
?>
