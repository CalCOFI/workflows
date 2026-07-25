-- query: TX - Cast
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cst_Cnt, Cast.Cruise, Cruises.Ship1, Cast.Sta_ID, Station_ID.Sta_Code
FROM Cruises INNER JOIN (Station_ID INNER JOIN Cast ON Station_ID.Sta_ID = Cast.Sta_ID) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cast.Cruise)=199702));
