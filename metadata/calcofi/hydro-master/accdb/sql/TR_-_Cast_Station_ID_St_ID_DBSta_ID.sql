-- query: TR - Cast & Station_ID: St_ID, DBSta_ID
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Cast.DbSta_ID, Cast.Sta_ID, Cast.Sta_Code, Cast.Cst_Cnt, Station_ID.Sta_ID
FROM Cast LEFT JOIN Station_ID ON Cast.DbSta_ID = Station_ID.DBSta_ID
WHERE (((Station_ID.Sta_ID) Is Null))
GROUP BY Cast.Year, Cast.Cruise, Cast.DbSta_ID, Cast.Sta_ID, Cast.Sta_Code, Cast.Cst_Cnt, Station_ID.Sta_ID;
