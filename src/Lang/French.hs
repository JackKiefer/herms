module Lang.French where

import Lang.Strings

french :: String -> String
french str
  | is tuiTitle       = "                                    Herm's - Ajouter une recette"
  | is tuiName        = "           Nom: "
  | is tuiDesc        = "   Description: "
  | is tuiServingSize = "       Portion: "
  | is tuiHeaders     = "                  qté.   unité              nom                 attribut"
  | is tuiIngrs       = "  Ingrédients: \n(un par ligne)  "
  | is tuiDirs        = "   Directions: \n(un par ligne)  "
  | is tuiTags        = "     Mots-clés: "
  | is tuiHelp1       = "                      Tab / Shift+Tab           - Champ suivant / précédent"
  | is tuiHelp2       = "                      Ctrl + <flêches>          - Parcourir les champs"
  | is tuiHelp3       = "                      [Meta or Alt] + <h-j-k-l> - Parcourir les champs"
  | is tuiHelp4       = "                      Esc                       - Enregistrer ou Annuler"
  | is headerServs    = "\nPortions: "
  | is headerIngrs    = "\nIngrédients:\n"
  | is saveRecipeYesNoEdit = "Enregister la recette? (O)ui  (N)on (E)diter"
  | is y              = "o"
  | is yCap           = "O"
  | is n              = "n"
  | is nCap           = "N"
  | is e              = "e"
  | is eCap           = "E"
  | is recipeSaved    = "Recette enregistrée!"
  | is changesDiscarded = "Modifications annulées."
  | is badEntry         = "Merci de SEULEMENT entrer 'o', 'n' ou 'e'"
  | is doesNotExist     = " n'existe pas\n"
  | is nothingToImport  = "Rien a importer"
  | is importedRecipes  = "Recettes importées:"
  | is metric         = "métrique"
  | is imperial       = "impériale"
  | is more           = " [plus]"
  | is capTags        = "Mots-clés"
  | is removingRecipe = "Enlever la recette: "
  | is group          = "grouper"
  --  | is groupShort     = "g"
  | is groupDesc      = "grouper les recettes par mots-cles"
  | is nameOnly       = "nom"
  --  | is nameOnlyShort  = "n"
  | is nameOnlyDesc   = "afficher que le nom des recettes"
  | is tags           = "mots-clés"
  | is tagsMetavar    = "MOTS-CLES"
  | is tagsDesc       = "afficher les recettes avec des mots-clés particuliers"
  | is serving        = "portion"
  --  | is servingShort   = "p"
  | is servingDesc    = "spécifier la portion en affichant"
  | is servingMetavar = "INT"
  | is step           = "pas"
  --  | is stepShort      = "t"
  | is stepDesc       = "s'il faut afficher un pas après l'autre"
  | is convert        = "convertir"
  --  | is convertShort   = "c"
  | is convertDesc    = "convertit les unités de la recette en métrique ou impérial."
  | is convertMetavar = "CONV_UNIT"
  | is none           = "aucun"
  | is recipeNameMetavar = "NOM_RECETTE"
  | is recipeNameDesc    = "index ou nom de recette"
  | is fileNameMetavar   = "NOM_FICHIER"
  | is fileNameDesc      = "nom du fichier"
  | is list           = "lister"
  | is listDesc       = "lister les recettes"
  | is view           = "afficher"
  | is viewDesc       = "afficher les recettes particulières"
  | is add            = "ajouter"
  | is addDesc        = "ajouter une nouvelle recette (interactivement)"
  | is edit           = "éditer"
  | is editDesc       = "éditer une recette"
  | is import'        = "importer"
  | is importDesc     = "importer un ficher de recette"
  | is remove         = "retirer"
  | is removeDesc     = "retirer les recettes particulières"
  | is shopping       = "course"
  | is shoppingDesc   = "générer une liste de course pour les recettes données"
  | is datadir        = "datadir"
  | is datadirDesc    = "afficher l'emplacement des fichers de configuration et de recettes"
  | is version        = "version"
  --  | is versionShort   = "v"
  | is versionDesc    = "afficher la version"
  | is progDesc       = "HeRM's: Un gestionnaire de recette en Haskell. Taper \"herms --help\" pour les options"
  | otherwise         = str

  where is = (str ==)
