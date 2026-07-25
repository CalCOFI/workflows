-- query: TR - Chl & Bottle: Btl_Cnt
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Chl.Btl_Cnt, Chl.ChlorA, Bottle.Btl_Cnt
FROM Bottle RIGHT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt
WHERE (((Bottle.Btl_Cnt) Is Null));
