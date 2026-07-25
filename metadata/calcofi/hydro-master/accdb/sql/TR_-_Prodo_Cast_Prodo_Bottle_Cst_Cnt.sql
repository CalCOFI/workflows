-- query: TR - Prodo_Cast & Prodo_Bottle: Cst_Cnt
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Cast.Sta_ID, Cast.Date, Prodo_Cast.Cst_Cnt
FROM Cast INNER JOIN (Prodo_Bottle RIGHT JOIN Prodo_Cast ON Prodo_Bottle.Cst_Cnt = Prodo_Cast.Cst_Cnt) ON Cast.Cst_Cnt = Prodo_Cast.Cst_Cnt
WHERE (((Prodo_Bottle.Cst_Cnt) Is Null));
