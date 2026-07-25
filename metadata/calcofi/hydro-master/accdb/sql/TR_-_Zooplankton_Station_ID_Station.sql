-- query: TR - Zooplankton & Station_ID: Station
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Zooplankton.Cruise AS Zoo_Cruise, Zooplankton.Sta_ID AS Zoo_St_ID, Station_ID.Sta_ID
FROM Zooplankton LEFT JOIN Station_ID ON Zooplankton.Sta_ID = Station_ID.Sta_ID
GROUP BY Zooplankton.Cruise, Zooplankton.Sta_ID, Station_ID.Sta_ID
HAVING (((Zooplankton.Cruise)>198400) AND ((Station_ID.Sta_ID) Is Null));
