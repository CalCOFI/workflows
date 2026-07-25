-- query: UQ-Rpt_Oxyumol/Kg_equation
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Rpt_Data
SET Rpt_Data.[R_Oxy_µmol/Kg] = (([Rpt_Data].[R_O2]*44660)/([Rpt_Data].[R_SIGMA]+1000))
WHERE (((Rpt_Data.R_O2) Is Not Null) AND ((Rpt_Data.Btl_Cnt)>862871));
