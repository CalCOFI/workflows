-- query: TR - Station_ID & Cast: DbSta_ID
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Station_ID.ID, Station_ID.Sta_ID, Station_ID.DBSta_ID, Station_ID.Sta_Code
FROM Station_ID LEFT JOIN Cast ON Station_ID.DBSta_ID = Cast.DbSta_ID
WHERE (((Cast.DbSta_ID) Is Null));
