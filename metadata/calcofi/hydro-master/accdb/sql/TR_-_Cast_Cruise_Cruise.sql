-- query: TR - Cast & Cruise: Cruise
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Count(Cast.Cruz_Sta) AS CountOfCruz_Sta
FROM Cast LEFT JOIN Cruises ON Cast.Cruise = Cruises.Cruise
WHERE (((Cruises.Cruise) Is Null))
GROUP BY Cast.Cruise;
