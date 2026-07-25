-- query: UQ-Rpt_R_Oxyumol/Kg
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast INNER JOIN (Bottle INNER JOIN Rpt_Data ON Bottle.Btl_Cnt = Rpt_Data.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
SET Rpt_Data.[R_Oxy_µmol/Kg] = [Bottle].[Oxy_µmol/Kg]
WHERE (((Cast.Cruise)=202304));
