-- query: Cast Query
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast INNER JOIN Prodo_Cast ON Cast.Cst_Cnt = Prodo_Cast.Cst_Cnt
SET Prodo_Cast.Cast_ID = [cast].[cast_ID]
WHERE (((Cast.cast_ID)<>[prodo_cast].[cast_ID]));
