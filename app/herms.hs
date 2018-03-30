{-# LANGUAGE ViewPatterns #-}

module Main where

import System.Directory
import System.IO
import Control.Monad
import Data.Function
import Data.List
import Data.Maybe
import Data.Semigroup ((<>))
import Data.Ratio
import Control.Applicative
import Options.Applicative hiding (str)
import Text.Read
import Utils
import AddCLI
import RichText
import Types
import UnitConversions
import ReadConfig
import Paths_herms

-- Global constants
versionStr :: String
versionStr = "1.8.2.0"

configPath :: IO FilePath
configPath = getDataFileName "config.hs"

-- | @getRecipeBookWith reads in recipe book with already read-in config
getRecipeBookWith :: Config -> IO [Recipe]
getRecipeBookWith config = do
  fileName <- getDataFileName (recipesFile config)
  contents <- readFile fileName
  return $ map read $ lines contents

-- | @getRecipeBook reads in config before reading in recipe book
getRecipeBook :: IO [Recipe]
getRecipeBook = do
  config <- getConfig
  getRecipeBookWith config

getRecipe :: String -> [Recipe] -> Maybe Recipe
getRecipe target = listToMaybe . filter ((target ==) . recipeName)

saveOrDiscard :: [[String]]   -- input for the new recipe
              -> Maybe Recipe -- maybe an original recipe prior to any editing
              -> IO ()
saveOrDiscard input oldRecp = do
  let newRecipe = readRecipe input
  putTextLn $ showRecipe newRecipe Nothing
  putStrLn "Save recipe? (Y)es  (N)o  (E)dit"
  response <- getLine
  if response == "y" || response == "Y"
    then do
    config <- getConfig
    recipeBook <- getRecipeBookWith config
    let recpName = maybe (recipeName newRecipe) recipeName oldRecp
    unless (isNothing (readRecipeRef recpName recipeBook)) $ removeSilent [recpName]
    fileName <- getDataFileName (recipesFile config)
    appendFile fileName (show newRecipe ++ "\n")
    putStrLn "Recipe saved!"
  else if response == "n" || response == "N"
    then
    putStrLn "Changes discarded."
  else if response == "e" || response == "E"
    then
    doEdit newRecipe oldRecp
  else
    do
    putStrLn "\nPlease enter ONLY 'y', 'n' or 'e'\n"
    saveOrDiscard input oldRecp

add :: IO ()
add = do
  input <- getAddInput
  saveOrDiscard input Nothing

doEdit :: Recipe -> Maybe Recipe -> IO ()
doEdit recp origRecp = do
  input <- getEdit (recipeName recp) (description recp) serving amounts units ingrs attrs dirs tag
  saveOrDiscard input origRecp
  where serving  = show $ servingSize recp
        ingrList = adjustIngredients (servingSize recp % 1) $ ingredients recp
        toStr f  = unlines (map f ingrList)
        amounts  = toStr (showFrac . quantity)
        units    = toStr unit
        ingrs    = toStr ingredientName
        dirs     = unlines (directions recp)
        attrs    = toStr attribute
        tag      = unlines (tags recp)

edit :: String -> IO ()
edit target = do
  recipeBook <- getRecipeBook
  case readRecipeRef target recipeBook of
    Nothing   -> putStrLn $ target ++ " does not exist\n"
    Just recp -> doEdit recp (Just recp)
  -- Only supports editing one recipe per command

-- | `readRecipeRef target book` interprets the string `target`
--   as either an index or a recipe's name and looks up the
--   corresponding recipe in the `book`
readRecipeRef :: String -> [Recipe] -> Maybe Recipe
readRecipeRef target recipeBook =
  (safeLookup recipeBook . pred =<< readMaybe target)
  <|> getRecipe target recipeBook

importFile :: String -> IO ()
importFile target = do
  config     <- getConfig
  recipeBook <- getRecipeBookWith config
  otherRecipeBook <- map read . lines <$> readFile target
  let recipeEq = (==) `on` recipeName
  let newRecipeBook = deleteFirstsBy recipeEq recipeBook otherRecipeBook
                        ++ otherRecipeBook
  replaceDataFile (recipesFile config) $ unlines $ show <$> newRecipeBook
  if null otherRecipeBook
  then putStrLn "Nothing to import"
  else do
    putStrLn "Imported recipes:"
    forM_ otherRecipeBook $ \recipe ->
      putStrLn $ "  " ++ recipeName recipe

getServingsAndConv :: Int -> String -> Config -> (Maybe Int, Conversion)
getServingsAndConv serv convName config = (servings, conv)
  where servings = case serv of
                   0 -> case defaultServingSize config of
                           0 -> Nothing
                           j -> Just j
                   i -> Just i
        conv = case convName of
               "metric"   -> Metric
               "imperial" -> Imperial
               _          -> defaultUnit config

view :: [String] -> Int -> String -> IO ()
view targets serv convName = do
  config     <- getConfig
  recipeBook <- getRecipeBookWith config
  let (servings, conv) = getServingsAndConv serv convName config
  forM_ targets $ \ target ->
    putText $ case readRecipeRef target recipeBook of
      Nothing   -> target ~~ " does not exist\n"
      Just recp -> showRecipe (convertRecipeUnits conv recp) servings

viewByStep :: [String] -> Int -> String -> IO ()
viewByStep targets serv convName = do
  config     <- getConfig
  recipeBook <- getRecipeBookWith config
  let (servings, conv) = getServingsAndConv serv convName config
  hSetBuffering stdout NoBuffering
  forM_ targets $ \ target -> case readRecipeRef target recipeBook of
    Nothing   -> putStr $ target ++ " does not exist\n"
    Just recp -> viewRecipeByStep (convertRecipeUnits conv recp) servings

viewRecipeByStep :: Recipe -> Maybe Int -> IO ()
viewRecipeByStep recp servings = do
  putText $ showRecipeHeader recp servings
  let steps = showRecipeSteps recp
  forM_ (init steps) $ \ step -> do
    putStr $ step ++ " [more]"
    getLine
  putStr $ last steps ++ "\n"

list :: [String] -> Bool -> Bool -> IO ()
list inputTags groupByTags nameOnly = do
  recipes <- getRecipeBook
  let recipesWithIndex = zip [1..] recipes
  let targetRecipes    = filterByTags inputTags recipesWithIndex
  if groupByTags
  then listByTags nameOnly inputTags targetRecipes
  else listDefault nameOnly targetRecipes

filterByTags :: [String] -> [(Int, Recipe)] -> [(Int, Recipe)]
filterByTags []        = id
filterByTags inputTags = filter (inTags . tags . snd)
 where
  inTags r = all (`elem` r) inputTags

listDefault :: Bool -> [(Int, Recipe)] -> IO ()
listDefault nameOnly (unzip -> (indices, recipes)) = do
  let recipeList = map showRecipeInfo recipes
      size       = length $ show $ length recipeList
      strIndices = map (padLeft size . show) indices
  if nameOnly
  then mapM_ (putStrLn . recipeName) recipes
  else mapM_ putTextLn $ zipWith (\ i -> ((i ~~ ". ") ~~)) strIndices recipeList

listByTags :: Bool -> [String] -> [(Int, Recipe)] -> IO ()
listByTags nameOnly inputTags recipesWithIdx = do
  let tagsRecipes :: [[(String, (Int, Recipe))]]
      tagsRecipes =
        groupBy ((==) `on` fst) $ sortBy (compare `on` fst) $
          concat $ flip map recipesWithIdx $ \recipeWithIdx ->
            map (flip (,) recipeWithIdx) $ tags $ snd recipeWithIdx
  forM_ tagsRecipes $ \tagRecipes -> do
    putTextLn $ bold $ fontColor Magenta $ fst $ head tagRecipes -- Tag name
    forM_ (map snd tagRecipes) $ \(i, recipe) ->
      if nameOnly
      then putStrLn $ recipeName recipe
      else putTextLn $ "  " ~~ show i ~~ ". " ~~ showRecipeInfo recipe
    putStrLn ""

showRecipeInfo :: Recipe -> RichText
showRecipeInfo recipe = name ~~ "\n\t" ~~ desc ~~ "\n\t[Tags: " ~~ showTags ~~ "]"
  where name     = fontColor Blue $ recipeName recipe
        desc     = (takeFullWords . description) recipe
        showTags = fontColor Green $ (intercalate ", " . tags) recipe

takeFullWords :: String -> String
takeFullWords = unwords . takeFullWords' 0 . words
  where takeFullWords' _ []                           = []
        takeFullWords' n [x]    | (length x + n) > 40 = []
                                | otherwise           = [x]
        takeFullWords' n (x:xs) | (length x + n) > 40 = [x ++ "..."]
                                | otherwise           =
                                  x : takeFullWords' (length x + n) xs

-- | @replaceDataFile fp str@ replaces the target data file @fp@ with
--   the new content @str@ in a safe manner: it opens a temporary file
--   first, writes to it, closes the handle, removes the target,
--   and finally moves the temporary file over to the target @fp@.

replaceDataFile :: FilePath -> String -> IO ()
replaceDataFile fp str = do
  (tempName, tempHandle) <- openTempFile "." "herms_temp"
  hPutStr tempHandle str
  hClose tempHandle
  fileName <- getDataFileName fp
  removeFile fileName
  renameFile tempName fileName

-- | @removeWithVerbosity v recipes@ deletes the @recipes@ from the
--   book, listing its work only if @v@ is set to @True@.
--   This subsumes both @remove@ and @removeSilent@.

removeWithVerbosity :: Bool -> [String] -> IO ()
removeWithVerbosity v targets = do
  config     <- getConfig
  recipeBook <- getRecipeBookWith config
  mrecipes   <- forM targets $ \ target -> do
    -- Resolve the recipes all at once; this way if we remove multiple
    -- recipes based on their respective index, all of the index are
    -- resolved based on the state the book was in before we started to
    -- remove anything
    let mrecp = readRecipeRef target recipeBook
    () <- putStr $ case mrecp of
       Nothing -> target ++ " does not exist.\n"
       Just r  -> guard v *> "Removing recipe: " ++ recipeName r ++ "...\n"
    return mrecp
  -- Remove all the resolved recipes at once
  let newRecipeBook = recipeBook \\ catMaybes mrecipes
  replaceDataFile (recipesFile config) $ unlines $ show <$> newRecipeBook

remove :: [String] -> IO ()
remove = removeWithVerbosity True

removeSilent :: [String] -> IO ()
removeSilent = removeWithVerbosity False


shop :: [String] -> Int -> IO ()
shop targets serv = do
  recipeBook <- getRecipeBook
  let getFactor recp
        | serv == 0 = servingSize recp % 1
        | otherwise = serv % 1
  let ingrts =
        concatMap (\target ->
          case readRecipeRef target recipeBook of
            Nothing   -> []
            Just recp -> adjustIngredients (getFactor recp) $ ingredients recp)
                  targets
  forM_ (sort ingrts) $ \ingr ->
    putStrLn $ showIngredient 1 ingr

printDataDir :: IO ()
printDataDir = do
  dir <- getDataDir
  putStrLn $ filter (/= '\"') (show dir) ++ "/"

-- Writes an empty recipes file if it doesn't exist
checkFileExists :: IO ()
checkFileExists = do
  config   <- getConfig
  fileName <- getDataFileName (recipesFile config)
  fileExists <- doesFileExist fileName
  unless fileExists (do
    dirName <- getDataDir
    createDirectoryIfMissing True dirName
    writeFile fileName "")

main :: IO ()
main = execParser commandPI >>= runWithOpts

-- @runWithOpts runs the action of selected command.
runWithOpts :: Command -> IO ()
runWithOpts (List tags group nameOnly)              = list tags group nameOnly
runWithOpts Add                                     = add
runWithOpts (Edit target)                           = edit target
runWithOpts (Import target)                         = importFile target
runWithOpts (Remove targets)                        = remove targets
runWithOpts (View targets serving step conversion)  = if step then viewByStep targets serving conversion
                                                      else view targets serving conversion
runWithOpts (Shop targets serving)                  = shop targets serving
runWithOpts DataDir                                 = printDataDir


------------------------------
------------ CLI -------------
------------------------------

-- | 'Command' data type represents commands of CLI
data Command = List   [String] Bool Bool         -- ^ shows recipes
             | Add                               -- ^ adds the recipe (interactively)
             | Edit    String                    -- ^ edits the recipe
             | Import  String                    -- ^ imports a recipe file
             | Remove [String]                   -- ^ removes specified recipes
             | View   [String] Int Bool String   -- ^ shows specified recipes with given serving
             | Shop   [String] Int               -- ^ generates the shopping list for given recipes
             | DataDir                           -- ^ prints the directory of recipe file and config.hs


listP, addP, editP, removeP, viewP, shopP, dataDirP :: Parser Command
listP    = List   <$> (words <$> tagsP) <*> groupByTagsP <*> nameOnlyP
addP     = pure Add
editP    = Edit   <$> recipeNameP
importP  = Import <$> fileNameP
removeP  = Remove <$> severalRecipesP
viewP    = View   <$> severalRecipesP <*> servingP <*> stepP <*> conversionP
shopP    = Shop   <$> severalRecipesP <*> servingP
dataDirP = pure DataDir


-- | @groupByTagsP is flag for grouping recipes by tags
groupByTagsP :: Parser Bool
groupByTagsP = switch
         (  long "group"
         <> short 'g'
         <> help "group recipes by tags"
         )

-- | @nameOnlyP is flag for showing recipe names only
nameOnlyP :: Parser Bool
nameOnlyP = switch
         (  long "name-only"
         <> short 'n'
         <> help "show only recipe names"
         )

-- | @tagsP returns the parser of tags
tagsP :: Parser String
tagsP = strOption (  long "tags"
                  <> value ""
                  <> metavar "TAGS"
                  <> help "show recipes with particular flags"
                  )

-- | @servingP returns the parser of number of servings.
servingP :: Parser Int
servingP =  option auto
         (  long "serving"
         <> short 's'
         <> help "specify serving size when viewing"
         <> showDefault
         <> value 0
         <> metavar "INT" )

stepP :: Parser Bool
stepP = switch
    (  long "step"
    <> short 't'
    <> help "Whether to show one step at a time" )

-- | @recipeNameP parses the string of recipe name.
recipeNameP :: Parser String
recipeNameP = strArgument (  metavar "RECIPE_NAME"
                          <> help "index or Recipe name")

-- | @fileNameP parses the string of a file name.
fileNameP :: Parser String
fileNameP = strArgument (  metavar "FILE_NAME"
                        <> help "file name")

-- | @severalRecipesP parses several recipe names at once
--   and returns the parser of list of names
severalRecipesP :: Parser [String]
severalRecipesP = many recipeNameP

-- | @conversionP flags recipes for unit conversion
conversionP :: Parser String
conversionP = strOption
            (long "convert"
            <> short 'c'
            <> help "Converts recipe units to either metric or imperial."
            <> metavar "CONV_UNIT"
            <> value "none")

-- @optP parses particular command.
optP :: Parser Command
optP =  subparser
     $  command "list"
                (info (helper <*> listP)
                      (progDesc "list recipes"))
     <> command "view"
                (info  (helper <*> viewP)
                       (progDesc "view the particular recipes"))
     <> command "add"
                (info  (helper <*> addP)
                       (progDesc "add a new recipe (interactively)"))
     <> command "edit"
                (info  (helper <*> editP)
                       (progDesc "edit a recipe"))
     <> command "import"
                (info  (helper <*> importP)
                       (progDesc "import a recipe file"))
     <> command "remove"
                (info  (helper <*> removeP)
                       (progDesc "remove the particular recipes"))
     <> command "shopping"
                (info (helper <*> shopP)
                      (progDesc "generate a shopping list for given recipes"))
     <> command "datadir"
                (info (helper <*> dataDirP)
                      (progDesc "show location of recipe and config files"))

versionOption :: Parser (a -> a)
versionOption = infoOption versionStr
                (long "version"
                <> short 'v'
                <> help "Show version")

-- @prsr is the main parser of all CLI arguments.
commandPI :: ParserInfo Command
commandPI =  info ( helper <*> versionOption <*> optP )
          $  fullDesc
          <> progDesc "HeRM's: a Haskell-based Recipe Manager. Type \"herms --help\" for options"
