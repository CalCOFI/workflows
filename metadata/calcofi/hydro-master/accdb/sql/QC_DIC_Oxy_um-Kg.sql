-- query: QC_DIC_Oxy_um-Kg
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Bottle.Depth_ID, Bottle.Sta_ID, DICs.DIC1, DICs.DIC2, DICs.TA1, DICs.TA2, DICs.Cruise, DICs.Salinity1, DICs.Salinity2, Bottle.Salnty, Bottle.[Oxy_µmol/Kg], DICs.Bottle_ID1
FROM Cast INNER JOIN (Bottle INNER JOIN DICs ON Bottle.Btl_Cnt = DICs.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((DICs.Cruise)=201507))
ORDER BY Bottle.Depthm;
