-- query: TR - Cast & Bottle: St_ID
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cst_Cnt, Cast.Cruise, Cast.Sta_ID, Bottle.Sta_ID, Bottle.Btl_Cnt, Cast.Order_Occ
FROM Cast INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Cast.Sta_ID)<>[Bottle]![Sta_ID]))
GROUP BY Cast.Cst_Cnt, Cast.Cruise, Cast.Sta_ID, Bottle.Sta_ID, Bottle.Btl_Cnt, Cast.Order_Occ;
