-- query: MK_Tbl_DICs_SalCompare
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Abs([bottle.Salnty]-[DICs.Salinity1]) AS SalComp, DICs.Depth_ID, DICs.Btl_Cnt, Bottle.Salnty, DICs.Salinity1, DICs.Bottle_ID1, DICs.Cruise, DICs.Comments INTO DIC_ABS_salCompare
FROM Bottle INNER JOIN DICs ON Bottle.Btl_Cnt = DICs.Btl_Cnt;
