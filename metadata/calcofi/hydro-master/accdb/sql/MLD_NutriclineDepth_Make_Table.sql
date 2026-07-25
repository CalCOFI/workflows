-- query: MLD_NutriclineDepth Make Table
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cast_ID, NutClineDepth.NCDepth AS Expr1 INTO [MLD_Nutricline new]
FROM Cast INNER JOIN NutClineDepth ON Cast.Cast_ID = NutClineDepth.Cast_ID
GROUP BY Cast.Cast_ID, NutClineDepth.NCDepth;
