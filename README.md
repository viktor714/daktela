# Keboola Daktela Extraktor
Daktela je cloudové řešení ústředny a CRM systému pro Call Centra. 
Etraktor se řídí  dle dokumentace podle [Daktela API V6](https://www.daktela.com/api/v6/). 

**Application input:**

- Daktela user account & password
- Start period specification
- Extractor Backend (Sequential, Parallel)

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

## Backend issues.
* Skript je napsaný v R 
* Používá knihovny zejména Tidyverse. 
* Podpora paralelní komputace pomocí knihovny Furrr a Futures. 
  - Defaultní hodnota je Sequential 
  - Vícejádrové verze jsou Multiprocess a  Multicore
* Paralelní zpracování je rychlejší, ale občas generuje chyby proto používat na vlastní nebezpečí. 
* Skript šetří paměť zdroje tím, že zapisuje stažené batche dat zdaktely přímo na disk. Pralelní processing může způsobit kolizi těchto jobů  proto doporučuju další testování. 

## Data issues
* Doporučuji stahovat data v noci kdy nejsou otevřené a nedokončené hovory. 
* Daktela občas vrací aktivitu např. email bez itemu takže aktivita type "Call" Může mít k sobě záznam kde ID_Call je null Skript tyto aktivity maže. 
* Skript omezuje data na záznamy které jsou staré alespoň 30 min aby se zamezilo importu neuzavřených záznamů.

## transformace dat
* Skript automaticky prefixuje názvy tabulek a indexy tak aby obsahovaly jméno ústředny.
* Tabulky digital engines se budou jmenovat digitalengines_activities
* Indexy jako name v tabulce activities budou upraveny na digitalengines_unikatní_id kvůli deduplikaci indexů při sloučení dat v ústředně. 
* Extraktor tahá vždy všechny atributy, které jsou podle dokumentace na první úrovni Jsonu, další atributy z vnořené struktury jsme volili arbitrárně. 
* Skript je řízen definicemi polí kde lze nastavit pole ke stažení + zda je pole klíč nebo ne. Klíče jsou prefixovány. 
* U tabulky activities skript extrahuje hlavičku, která je stejná pro všechny itemy
* Itemy activities jsou řešeny filtrem kde se tahá id aktivity plus item atributy jednou pro call ,jednou pro chaty a jednou pro emaily. 
* Itemy activites nemají unikátní klíč proto generuju ve skriptu unikátní složený klíč unique_id
* Skript nestahuje itemy, které nemají aktivitu oprátora. Jedná se mmj o emailový SPAM. 
