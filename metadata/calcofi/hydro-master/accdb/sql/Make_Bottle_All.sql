-- query: Make Bottle_All
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Bottle.*, Bottle_Q.*, Chl.*, Nuts.*, Prodo_Bottle.*, Rpt_Data.R_PRES, Rpt_Data.R_POTEMP, Rpt_Data.R_SVA, Rpt_Data.R_DYNHT, Rpt_Data.R_NH4, Rpt_Data.[R_Oxy_µmol/Kg], DICs.DIC1, DICs.DIC2, DICs.TA1, DICs.TA2, DICs.pH1, DICs.pH2, DICs.Btl_Cnt, DICs.[DIC Quality Comment] INTO Bottle_All_2105
FROM Cast INNER JOIN ((((((Bottle LEFT JOIN DICs ON Bottle.Btl_Cnt = DICs.Btl_Cnt) INNER JOIN Bottle_Q ON Bottle.Btl_Cnt = Bottle_Q.Btl_Cnt) INNER JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) INNER JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) INNER JOIN Prodo_Bottle ON Bottle.Btl_Cnt = Prodo_Bottle.Btl_Cnt) INNER JOIN Rpt_Data ON Bottle.Btl_Cnt = Rpt_Data.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Cast.Cruise)<=202105));
