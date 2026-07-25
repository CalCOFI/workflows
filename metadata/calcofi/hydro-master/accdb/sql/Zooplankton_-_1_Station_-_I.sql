-- query: Zooplankton - 1 Station - I
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Avg(Year(Zooplankton!Tow_Date)) AS Year, Cruises.Cruise, St_Stations.St_Line, Zooplankton.Sta_ID, St_Stations.Sta_ID, Zooplankton.Tow_Date AS Date, Avg(Month(Zooplankton!Tow_Date)+Day(Zooplankton!Tow_Date)/30.5-1) AS Month, Count(Zooplankton.Ttl_PVolC3) AS NoSamples, Zooplankton.Ttl_PVolC3 AS T_Zoo, Zooplankton.Sml_PVolC3 AS S_Zoo, Avg(Log([T_Zoo])) AS Log_TZoo, Avg(Log([S_Zoo])) AS Log_SZoo
FROM St_Stations INNER JOIN (Cruises INNER JOIN Zooplankton ON Cruises.Cruise = Zooplankton.Cruise) ON St_Stations.Sta_ID = Zooplankton.Sta_ID
WHERE (((Cruises.[Code-ST])="st") AND ((Zooplankton.Ttl_PVolC3)>0) AND ((Zooplankton.Net_Loc)="S"))
GROUP BY Cruises.Cruise, St_Stations.St_Line, Zooplankton.Sta_ID, St_Stations.Sta_ID, Zooplankton.Tow_Date, Zooplankton.Ttl_PVolC3, Zooplankton.Sml_PVolC3
ORDER BY Cruises.Cruise, Zooplankton.Sta_ID;
