workspace "TicketRush" {
  model {
    acheteur = person "Acheteur" "Achète des billets lors des mises en vente"
    organisateur = person "Organisateur" "Suit ses ventes en temps réel"
    ticketrush = softwareSystem "TicketRush" "Billetterie à forte affluence"
    paiement = softwareSystem "Prestataire de paiement" "Simulé et instable" "External"

    acheteur -> ticketrush "Rejoint la file, réserve, paie" "HTTPS"
    organisateur -> ticketrush "Consulte le tableau de bord" "HTTPS"
    ticketrush -> paiement "Débite le client" "HTTPS"
  }
  views {
    systemContext ticketrush { include * autolayout lr }
    styles { element "External" { background #999999 } }
  }
}