-- query: Prodo_NameProb
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cast_ID, Cast.Cruise, Cast.Sta_ID, Cast.Cst_Cnt, Prodo_Bottle.MeanAs, Prodo_Cast.IntC14, Cast.IntC14, Bottle.Depth_ID, Cast.Data_Type, Bottle.Btl_Cnt, Prodo_Cast.Civil_T, Cast.Cruise_ID
FROM (Prodo_Cast INNER JOIN Bottle ON Prodo_Cast.Cst_Cnt = Bottle.Cst_Cnt) INNER JOIN (Cast INNER JOIN Prodo_Bottle ON Cast.Cst_Cnt = Prodo_Bottle.Cst_Cnt) ON (Prodo_Cast.Cst_Cnt = Prodo_Bottle.Cst_Cnt) AND (Cast.Cst_Cnt = Prodo_Cast.Cst_Cnt) AND (Cast.Cst_Cnt = Bottle.Cst_Cnt) AND (Bottle.Btl_Cnt = Prodo_Bottle.Btl_Cnt)
WHERE (((Cast.Cst_Cnt)=23954));
