-- query: TR - Prodo_Cast & Cast: Cst_Cnt
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Prodo_Cast.Cst_Cnt, Prodo_Cast.Cast_ID AS Expr1
FROM Cast RIGHT JOIN Prodo_Cast ON Cast.Cst_Cnt = Prodo_Cast.Cst_Cnt
WHERE (((Cast.Cst_Cnt)=[prodo_cast].[cst_cnt]) AND ((Cast.Cast_ID)<>[Prodo_Cast].[Cast_ID]));
