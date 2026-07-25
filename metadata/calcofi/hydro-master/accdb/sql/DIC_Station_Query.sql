-- query: DIC_Station_Query
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Bottle.Depthm, Bottle.Sta_ID, Cast.Cruise, DICs.DIC1, DICs.Salinity1, Bottle.Salnty, Bottle.O2ml_L, Bottle.RecInd, DICs.TA1, Bottle.[Oxy_µmol/Kg]
FROM Cast INNER JOIN (Bottle LEFT JOIN DICs ON Bottle.Btl_Cnt = DICs.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Bottle.Sta_ID)="081.8 046.9") AND ((Cast.Cruise)=201004) AND ((Bottle.RecInd)=3))
ORDER BY Bottle.Depthm;
