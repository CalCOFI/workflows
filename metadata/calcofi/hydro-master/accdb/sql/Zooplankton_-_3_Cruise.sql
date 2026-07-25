-- query: Zooplankton - 3 Cruise
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Zooplankton - 2 Station].Year, [Zooplankton - 2 Station].Cruise, Avg([Zooplankton - 2 Station].Date) AS Date, Avg([Zooplankton - 2 Station].Month) AS Month, Avg([Zooplankton - 2 Station].T_Zoo) AS T_Zoo, Avg([Zooplankton - 2 Station].S_Zoo) AS S_Zoo, Avg([Zooplankton - 2 Station].Log_TZoo) AS Log_TZoo, Avg([Zooplankton - 2 Station].Log_SZoo) AS Log_SZoo, Count([Zooplankton - 2 Station].T_Zoo) AS SampCount
FROM [Zooplankton - 2 Station]
GROUP BY [Zooplankton - 2 Station].Year, [Zooplankton - 2 Station].Cruise
ORDER BY [Zooplankton - 2 Station].Cruise;
