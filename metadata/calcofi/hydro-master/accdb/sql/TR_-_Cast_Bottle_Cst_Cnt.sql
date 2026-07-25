-- query: TR - Cast & Bottle: Cst_Cnt
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cst_Cnt, Cast.Cruise, Cast.Sta_ID, Bottle.Cst_Cnt
FROM Cast LEFT JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Bottle.Cst_Cnt) Is Null));
