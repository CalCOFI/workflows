-- query: TR - Zooplankton & Cast: Cruise
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Zooplankton.Cruise, Count(Zooplankton.Sta_ID) AS CountOfSta_ID
FROM Cast RIGHT JOIN Zooplankton ON Cast.Cruz_Sta = Zooplankton.Cruz_Sta
WHERE (((Cast.Cruise) Is Null))
GROUP BY Zooplankton.Cruise;
