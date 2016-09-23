<?php

include_once('utils.php');

set_time_limit(5);

$commande = 'poweroff';    // commande shell à envoyer à la machine cible.
 
// Etablissement de la connexion ssh2, port 22
if (false === $connection = ssh2_connect($hostname, 22)) {
  exit();  // sortie si erreur
  }

//authentification utilisateur
if (false === ssh2_auth_password($connection, $username, $password)) {
  exit(); // sortie si erreur
  }
 
//exécution command shell sur la machine destinataire
if (false === $stream = ssh2_exec($connection, $commande)) {
  }
 
// sortie du résultat quand il y en a un
stream_set_blocking($stream, true);
$output = '';
while($ligne = fgets($stream)) {
  $output = $output . $ligne . '<br />';
  }

// Sortie de l'erreur quand il y en a une
$stderr = ssh2_fetch_stream($stream, SSH2_STREAM_STDERR);
stream_set_blocking($stderr, true);
$output = '';
while($ligne = fgets($stderr)) {
  $output = $output . $ligne . '<br />';
  }
fclose($stderr);
fclose($stream);
?>
