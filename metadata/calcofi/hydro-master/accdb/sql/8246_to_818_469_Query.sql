-- query: 8246 to 818 469 Query
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Bottle.Cst_Cnt, Bottle.Sta_ID AS Bottle_Sta_ID, Bottle.Depth_ID, Cast.DbSta_ID, Cast.Sta_ID AS Cast_Sta_ID, Cast.Cast_ID
FROM Cast INNER JOIN Bottle ON Cast.[Cst_Cnt] = Bottle.[Cst_Cnt];
