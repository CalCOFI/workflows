-- query: TR - Nuts & Bottle: Btl_Cnt
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Nuts.Btl_Cnt, Nuts.PO4ug AS Expr1, Bottle.Btl_Cnt
FROM Nuts LEFT JOIN Bottle ON Nuts.Btl_Cnt = Bottle.Btl_Cnt
WHERE (((Bottle.Btl_Cnt) Is Null));
