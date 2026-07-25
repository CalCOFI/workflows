-- query: Mati_Hydro_Query
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Bottle.Sta_ID, Bottle.Depthm, Bottle.T_degC, Bottle.Salnty, Bottle.O2ml_L, Chl.ChlorA, Chl.Phaeop, Nuts.PO4uM, Nuts.SiO3uM, Nuts.NO2uM, Nuts.NO3uM, Nuts.NH3uM, Bottle.Cst_Cnt, Bottle.Btl_Cnt, Bottle.STheta, Bottle.O2Sat, Bottle.[Oxy_µmol/Kg] INTO [Mati_Hydro_1902-2107_finalthru2001]
FROM Cast INNER JOIN ((Bottle INNER JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) INNER JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Cast.Cruise) Between 202204 And 202208) AND ((Bottle.RecInd)=3));
