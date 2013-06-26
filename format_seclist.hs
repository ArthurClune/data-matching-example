{-# LANGUAGE OverloadedStrings #-}

--
-- Given output from seclist, print it in a suitable format for the squidlog parsing stuff
--

import           Control.Error        (tryIO, runEitherT)
import           Data.Either          (Either(..), lefts, rights)
import           Data.List            (groupBy, partition)
import qualified Data.List as L
import qualified Data.Map as M
import           Data.Map             (Map, (!))
import           Data.Maybe           (catMaybes)
import           Network.BSD          (HostEntry(..), getHostByName)
import           Network.Socket       (inet_ntoa)
import           Safe                 (abort)
import           System.Environment   (getArgs)

months = M.fromList [
                ("01", "Jan"),
                ("02", "Feb"),
                ("03", "Mar"),
                ("04", "Apr"),
                ("05", "May"),
                ("06", "Jun"),
                ("07", "Jul"),
                ("08", "Aug"),
                ("09", "Sep"),
                ("10", "Oct"),
                ("11", "Nov"),
                ("12", "Dec")
            ]

data Line = Line {
    luser   :: String,
    lipaddr :: String,
    ldate   :: String,
    ltime   :: String,
    ltype   :: String
}

instance Show Line where
    show l = lipaddr l ++ " " ++ ldate l ++ " " ++ ltime l ++ " " ++ ltype l

data Event = Event {
    user      :: String,
    ipaddr    :: String,
    startDate :: String,
    endDate   :: String,
    startTime :: String,
    endTime   :: String
}

instance Show Event where
    show e = ipaddr e ++ " " ++ formatTime (startDate e) (startTime e)
                      ++ " " ++ formatTime (endDate e) (endTime e)
      where
        formatTime d t = format_date ++ " " ++ t
          where
            format_date = day ++ " " ++ mth ++ " " ++ yr
            day = take 2 d
            mth = months ! take 2 (drop 3 d)
            yr  = take 4 $ drop 6 d

getHost::String -> IO String
getHost name = do
        res <- runEitherT $ tryIO $ getHostByName name
        case res of
            Left  _ -> return name
            Right v -> inet_ntoa $ head (hostAddresses v)

-- very simple cmdargs handler
parseArgs::IO String
parseArgs = do
    args <- getArgs
    if length args == 1
        then return (head args)
        else abort "Usage: format_seclist [file1]"

-- Convert list of strings to parsed items
parseInput::[String] -> IO (Maybe Line)
parseInput [user, host, date, time, _, inout] = do
    ipaddr <- getHost host
    return $ Just (Line user ipaddr date time inout)
parseInput [] = return Nothing

-- Given a list of lines all from the same host
-- match up login/logout times return a pair
-- ([matched events], [unmatched lines)]
matchEntries::[Line] -> ([Event], [Line])
matchEntries ls = (rights matches, lefts matches)
  where
    matches = catMaybes $ zipWith matchPairs ls (tail ls) ++ [matchLastEntry ls]
    matchPairs e1 e2 = case (ltype e1, ltype e2) of
                            ("LOGIN", "LOGOUT")  -> Just (Right $ makeEvent e1 e2)
                            ("LOGIN", "LOGIN")   -> Just (Left e1)
                            ("LOGOUT", "LOGIN")  -> Nothing
                            ("LOGOUT", "LOGOUT") -> Just (Left e2)
    -- check if we ignored the last entry or not
    matchLastEntry []  = Nothing
    matchLastEntry [x] = Just (Left x)
    matchLastEntry ls  = case (ltype e1, ltype e2) of
                                 ("LOGIN", "LOGIN")   -> Just (Left e2)
                                 ("LOGOUT", "LOGIN")  -> Just (Left e2)
                                  -- other cases already covered in matchPairs
                                 (_      , _)         -> Nothing
      where
         e1 = last $ init ls
         e2 = last ls

    makeEvent e1 e2 = Event (luser e1) (lipaddr e1) (ldate e1)
                                                (ldate e2) (ltime e1) (ltime e2)

-- group the list of entries by host/ip
groupByHost::[Line] -> [[Line]]
groupByHost parsedLines = M.elems $ foldl f M.empty parsedLines
  where
    f m x  = M.insertWith (flip (L.++) ) (lipaddr x) [x] m

main = do
    s <- parseArgs >>= readFile
    let parts = map words (lines s)
    parsedLines <- mapM parseInput parts
    let linesByHost = groupByHost $ catMaybes parsedLines
    mapM_ (printResults . matchEntries) linesByHost
  where
    printResults (events, ignored) = do
        mapM_ (\e -> putStrLn $ "Ignored line: " ++ show e) ignored
        mapM_ print events
