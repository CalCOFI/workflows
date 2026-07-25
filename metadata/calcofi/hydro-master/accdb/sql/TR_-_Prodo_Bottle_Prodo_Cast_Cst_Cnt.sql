-- query: TR - Prodo Bottle & Prodo_Cast: Cst_Cnt
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Prodo_Bottle.Cst_Cnt AS Expr1, Prodo_Bottle.Btl_Cnt
FROM Prodo_Bottle, Prodo_Cast
WHERE (((Prodo_Cast.Cst_Cnt) Is Null));
