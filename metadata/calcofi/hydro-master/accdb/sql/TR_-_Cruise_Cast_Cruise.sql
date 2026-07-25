-- query: TR - Cruise & Cast: Cruise
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cruises.Cruise
FROM Cast RIGHT JOIN Cruises ON Cast.Cruise = Cruises.Cruise
WHERE (((Cast.Cruise) Is Null))
GROUP BY Cruises.Cruise;
