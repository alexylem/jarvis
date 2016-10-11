# Description
Permet d'allumer ou d'éteindre un serveur (compatible wake on lan pour 
l'éveil et disposant du ssh pour l'extinction).

Les trois php sont dans le dossier du store /store/all/fr_wake_sleep_server

Pour l'installation : 
    - Dans utils.php il faut mettre l'ip de la machine à allumer, 
    le user et le pass ssh de la machine distante. Pensez ensuite à réduire 
    les droits d'accès en lecture écriture à ce fichier.

    - Dans wakenas.php mettre l'adresse mac de la machine à allumer et si votre machine est sur 
    une IP différente de 192.168.0.X comme par exemple 192.168.1.X, pensez à modifier l'adresse de 
    broadcast de 192.169.0.255 à 192.168.1.255

    - Dans shutdown.php pensez à modifier le chemin d'accès à utils.php si vous le mettez dans un répertoire
    différent. Modifier la variable $commande avec la commande ssh à éxecuter sur la machine distante. 
    "poweroff" par défaut

    - Dans le fichier de commande les chemins d'accès des fichiers php seront peut être à adapter


# Usage
Vous: Allume le serveur s'il te plait
Jarvis: allumage en cours
Vous : Etein le serveur s'il te plait
jarvis : Extinction en cours

# Author & Contributors
Rbillon
