module Assini where

-- See http://www.cse.ogi.edu/~andy/html/intro.htm
import Text.Html


{- Family Data Model -}

unknown = []

data Country = ITALY | TAIWAN | UK | USA | FRANCE | AUSTRALIA | BRASIL deriving (Eq,Show)

data Place = Place {country::Country,county::String,place::String} deriving (Eq,Show)
pl = Place {country=undefined,county=unknown,place=unknown}
tw = pl {country=TAIWAN}
fr = pl {country=FRANCE}
uk= pl {country=UK}
it = pl {country=ITALY}
fi = it {place="Firenze"}
smarco = it {county="Benevento",place="S.Marco dei Cavoti"}

type Date = String

data Event = At {space::Place,time::Date} deriving (Eq,Show)

data Sex = MALE | FEMALE deriving (Eq,Show)

data Person = Person {
  sex :: Sex
  ,firstName :: String
  ,middleName :: String
  ,nickName :: String
  ,lastName :: String
  ,born :: Event
  ,died :: Event
  ,email :: String
  ,homePage :: String
  ,description :: String
  ,families :: [Family] -- set only for direct descendants, list of families (in chronological order)
} deriving (Eq,Show)

person = Person {sex=undefined,firstName=unknown,middleName=unknown,nickName=unknown,lastName=unknown,born=undefined,died=undefined,description=unknown,email=unknown,homePage=unknown,families=unknown} 
male = person {sex=MALE}
female = person {sex=FEMALE}

assini = Person {sex=undefined,firstName=unknown,middleName=unknown,nickName=unknown,lastName="Assini",born=undefined,died=undefined,description=unknown,email=unknown,homePage=unknown,families=unknown}
m = assini {sex=MALE}
f = assini {sex=FEMALE}

data Family = Family {spouse::Person,children::[Person],marriage::Event} deriving (Eq,Show)

family houseHead sp ch = houseHead {families=[Family {spouse=sp,children=ch,marriage=undefined}]}

extFamily houseHead sp ch m = houseHead {families=[Family {spouse=sp,children=ch,marriage=m}]}

{- Assini's family members -}

{- Massimo Assini -}

branch_mercato = pasquale   
 where -- Create an entry for every person in the main line that has a family
   titto = extFamily m {firstName="Pasqualino",nickName="Titto",born=At fi "1965/06/11",description="Administers the Assini's Family Website",email="titto@kamus.it",homePage="http://www.kamus.it/titto"} f {firstName="Chao-Mi",lastName="Ko",born=At tw "1967/04/21"} [f {firstName="Libera",middleName="Zi-Zai",born=At fi "1995/10/25"}, m {firstName="Leo",middleName="Zi-You", born=At uk{place="Colchester"} "2000/02/07"}]  (At fi "1995/10/14")   
   dad = extFamily m {firstName="Nicola",born=At smarco "1933?"} f {firstName="Cristina",lastName="Ielardi",born=At smarco "1931?"} [titto] (At it unknown)
   stef = family f {firstName="Stefanina",born=At smarco unknown,died=At smarco unknown} 
      m {firstName="Vittorio",lastName="Costantini",died=At smarco unknown} [antonio,caterina,fernando]
   antonio = m{firstName="Antonio",lastName="Costantini",born=At smarco unknown}
   caterina = family f{firstName="Caterina",lastName="Costantini",born=At smarco unknown} male [male {firstName="David"}] 
   fernando = family m{firstName="Fernando",lastName="Costantini",born=At smarco unknown} female [female {firstName="Stefania",lastName="Costantini",born=At smarco unknown}]
   cristina = family f{firstName="Cristina",lastName="Flaviano",born=At it{place="Caserta"} unknown} m{firstName="Eduardo",lastName="Oliva"} [m{firstName="Antonia",lastName="Oliva",born=At it{place="Caserta?"} unknown}]
   federico = family m{firstName="Cristina",lastName="Flaviano",born=At it{place="Caserta"} unknown} m{firstName="Maria"} [m{firstName="Edoardo",lastName="Flaviano",born=At it{place="Roma?"} "1988?"},m{firstName="?",lastName="Flaviano",born=At it{place="Roma?"} unknown}]
   anna = family f{firstName="Anna", born=At smarco unknown} m{firstName="Eduardo",lastName="Flaviano"} [cristina,federico]
   giovanni = family m{firstName="Giovanni",lastName="Colarusso",born=At smarco "1965?"} female [f{firstName="Odillia",lastName="Colarusso",born=At smarco unknown},m{firstName="Nicola",lastName="Colarusso",born=At smarco unknown}]    
   odillia = family f{firstName="Odillia",born=At smarco unknown} male{firstName="Nicola",lastName="Colarusso",born=At smarco unknown} [giovanni,female{firstName="Giuseppina",lastName="Colarusso",born=At smarco unknown}]
   luigi = family m{firstName="Luigi",born=At smarco unknown} female{firstName="Regine",lastName="Boutégège",born=At fr unknown} [f{firstName="Pascale",born=At fi "1980?"},f{firstName="Lisa",born=At fi "1983?"}]
   ant = family m{firstName="Antonio",born=At smarco unknown} female{firstName="Gianna",lastName="Gnasso",born=At it{place="Mondragone?"} unknown} [m{firstName="Simone",born=At fi "1975?"},m{firstName="Massimo",born=At fi "1979?"}]
   giov = family m{firstName="Giovanni",born=At smarco unknown} female{firstName="Simonetta",lastName="Ducci"} [female{firstName="Maria Antonietta",born=At fi "1978?"},female{firstName="Annamaria",born=At fi "1982?"},female{firstName="Maria Laura",born=At fi "1988?"}]
   pasquale = family m {firstName="Pasquale",born=At smarco unknown} f {firstName="Antonietta",lastName="Pomarico"} 
      [stef,m{firstName="Massimo",born=At smarco unknown},dad,anna,odillia,luigi,ant,giov]   

{- 
Pasqualino "Titto" Assini[father->is Nicola Assini, mother is Cristina Ielardi . 
-}


{- HTML Output -}

toCell :: (HTML a) => a -> Html
toCell s = td ! [align "center"] << font ![size "3",face "Arial"] << s

onTop top down = toCell top `above` down

single x = besides [x]

toHTML (Person{firstName=name,families=[]}) = single (toCell name)

toHTML (Person{firstName=name,families=[Family{children=ch,spouse=Person{firstName=spouseName}}]}) = 
  (name ++ " - " ++ spouseName)`onTop` besides (map toHTML ch)
		
assinis :: Html
assinis = table ! [border 1] << toHTML branch_mercato

main = do writeFile "c:\\temp\\page.html" ("<h1>Assini's page</h1>" ++ (show assinis) ++ "<P>" ++ (show (debugHtml assinis)))


