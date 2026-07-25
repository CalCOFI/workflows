-- query: TR - Bottle & Cast: Cst_Cnt
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Bottle.Cst_Cnt, Bottle.Sta_ID, Bottle.Depth_ID
FROM Cast INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Cast.Cst_Cnt) Is Null));
