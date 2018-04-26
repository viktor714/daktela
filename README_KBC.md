Daktela - Extractor for Keboola allowing automated downloads (R script).

Daktela kontaktní centrum je cloudové řešení callcentra s nativní podporou mnoha komunikačních kanálů "OmniChannel" v jedné webové aplikaci - telefon, email s helpdeskem, webový chat, SMS a sociální sítě.

________________________________________________________________________________________

**Application input:**

- Daktela user account & password
- Start period specification

**This component allows you to extract:**

1. Activities
2. ActivitiesCall
3. ActivitiesEmail
4. ActivitiesChat
5. Accounts
6. Groups
7. Pauses
8. Queues
9. Statuses
10.Templates
11.Tickets

Detailed API documentation available here:
https://www.daktela.com/api/v6/

There are no specified primary keys of imported tables. Instead, user must set the primary keys manually in the KBC UI within the STORAGE section after the first successfull import.

**R script details**
Skript automaticky prefixuje názvy tabulek a indexy tak aby obsahovaly jméno ústředny.
Tabulky digital engines se budou jmenovat digitalengines_activities
Indexy jako name v tabulce activities budou upraveny na digitalengines_unikatní_id kvůli deduplikaci indexů při sloučení dat v ústředně.
Extraktor tahá vždy všechny atributy, které jsou podle dokumentace na první úrovni Jsonu, další atributy z vnořené struktury jsme volili arbitrárně.
Skript je řízen definicemi polí kde lze nastavit pole ke stažení + zda je pole klíč nebo ne. Klíče jsou prefixovány.
U tabulky activities skript extrahuje hlavičku, která je stejná pro všechny itemy
Itemy activities jsou řešeny filtrem kde se tahá id aktivity plus item atributy jednou pro call ,jednou pro chaty a jednou pro emaily.
Skript nestahuje itemy, které nemají aktivitu oprátora. Jedná se mmj o emailový SPAM.
Skript nepoužívá multijádrový processing. V případě nutnosti optimalizace doporučuji přehodit smyčku ve funkci write endpoint na parallelní processing. (rows_fetched<-map(i,function(i){})
Pozn. 180 dní hovorů digital engines se stahuje 4 hodiny.
