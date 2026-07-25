-- query: NH4
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Cast.Sta_ID, Bottle.Cst_Cnt, Bottle.Btl_Cnt, Bottle.Depthm, Cast.Order_Occ, NH4_Data.[NH4_uM/l] AS Expr1 INTO NH4_DB
FROM NH4_Data, Cast INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((NH4_Data.Cruise)=[cast].[cruise]) AND ((NH4_Data.Order_Occ)=[Cast].[order_occ]) AND (([NH4_Data].[Btlnum])=[bottle].[btlnum]));
