-- query: TR - Cruise & Zooplankton: Cruise
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cruises.Cruise, Cruises.[Code-ST]
FROM Cruises LEFT JOIN Zooplankton ON Cruises.Cruise = Zooplankton.Cruise
WHERE (((Zooplankton.Cruise) Is Null))
GROUP BY Cruises.Cruise, Cruises.[Code-ST]
HAVING (((Cruises.Cruise)>198400) AND ((Cruises.[Code-ST])="st"));
