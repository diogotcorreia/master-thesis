#import "../utils/constants.typ": TheTool
#import "../content/ch05-results.typ": raw_data

Under de senaste decennierna
har attacker med återanvändning av kod visat hur illvilliga parter
kan förändra ett programs normala exekveringsflöde
genom att utnyttja godartad kod som redan finns i applikationen.
Klassförorening i programmeringsspråket Python
är en ny variant av en attack med återanvändning av kod,
som kan göra det möjligt för en illvillig aktör att kirurgiskt mutera en variabel
i vilken del av applikationen
som helst för att utlösa en förändring i dess exekveringsflöde.

Hittills har dock
lite eller ingen forskning undersökt klassförorening i detalj,
och inget verktyg finns lättillgängligt för att upptäcka den.
Av denna anledning
har en litteraturöversikt om orsakerna till och konsekvenserna av klassförorening
genomförts som en del av detta examensarbete,
utöver den metodiska utvecklingen av ett verktyg
som kan upptäcka klassförorening, #TheTool.

Dessutom har en empirisk studie om förekomsten av klassförorening
i verklig Python-kod utförts genom att köra #TheTool
mot en datauppsättning med #raw_data.len() Python-projekt,
vilket framför allt avslöjade en kritisk sårbarhet i ett populärt PyPI-paket
med mer än 30 miljoner nedladdningar.
Denna sårbarhet möjliggjorde överbelastningsattack och fjärrkodexekvering,
som sedan dess har avslöjats och patchats på ett ansvarsfullt sätt.

Sammantaget visade resultaten att även om
inte många verkliga Python-projekt är känsliga för klassföroreningar,
är det en sårbarhet som måste beaktas när man bygger en säker applikation
på grund av de allvarliga konsekvenser det kan leda till.
