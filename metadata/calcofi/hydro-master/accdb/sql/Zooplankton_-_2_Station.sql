-- query: Zooplankton - 2 Station
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Zooplankton - 1 Station - I].Year, [Zooplankton - 1 Station - I].Cruise, [Zooplankton - 1 Station - I].St_Line, [Zooplankton - 1 Station - I].Zooplankton.Sta_ID AS St_ID, Avg([Zooplankton - 1 Station - I].Date) AS Date, Avg([Zooplankton - 1 Station - I].Month) AS Month, Avg([Zooplankton - 1 Station - I].T_Zoo) AS T_Zoo, Avg([Zooplankton - 1 Station - I].S_Zoo) AS S_Zoo, Avg([Zooplankton - 1 Station - I].Log_TZoo) AS Log_TZoo, Avg([Zooplankton - 1 Station - I].Log_SZoo) AS Log_SZoo, Count([Zooplankton - 1 Station - I].Log_SZoo) AS No_Stations
FROM [Zooplankton - 1 Station - I]
GROUP BY [Zooplankton - 1 Station - I].Year, [Zooplankton - 1 Station - I].Cruise, [Zooplankton - 1 Station - I].St_Line, [Zooplankton - 1 Station - I].Zooplankton.Sta_ID
ORDER BY [Zooplankton - 1 Station - I].Cruise, [Zooplankton - 1 Station - I].Zooplankton.Sta_ID;
