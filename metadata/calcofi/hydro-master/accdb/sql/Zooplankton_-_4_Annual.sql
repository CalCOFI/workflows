-- query: Zooplankton - 4 Annual
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Zooplankton - 3 Cruise].Year, Avg([Zooplankton - 3 Cruise].Date) AS Date, Avg([Zooplankton - 3 Cruise].T_Zoo) AS T_Zoo, Avg([Zooplankton - 3 Cruise].S_Zoo) AS S_Zoo, Avg([Zooplankton - 3 Cruise].Log_TZoo) AS Log_TZoo, Avg([Zooplankton - 3 Cruise].Log_SZoo) AS Log_SZoo, Count([Zooplankton - 3 Cruise].T_Zoo) AS No_Cruises
FROM [Zooplankton - 3 Cruise]
WHERE ((([Zooplankton - 3 Cruise].Cruise)<>198505 And ([Zooplankton - 3 Cruise].Cruise)<>198711))
GROUP BY [Zooplankton - 3 Cruise].Year;
