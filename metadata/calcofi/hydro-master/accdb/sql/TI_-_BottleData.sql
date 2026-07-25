-- query: TI - BottleData
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.[Cast_ID] AS Cast_Num, Bottle.[Btl_Cnt] AS Btl_Num, Cast.Cst_Cnt, Cast.Cruise, Cast.Order_Occ, Cast.Date, Cast.Time, [Date]+[Time] AS DateTime, Cast.St_Line, Cast.Cast_ID, Bottle.Sta_ID, Cast.Sta_Code, Cast.Lat_Dec, Cast.Lon_Dec, Cast.Distance, Bottle.Btl_Cnt, Bottle.BtlNum, Bottle.Depthm, Bottle.T_degC, Bottle.Salnty, Bottle.STheta, Bottle.O2ml_L, Bottle.O2Sat, Nuts.PO4uM, Nuts.SiO3uM, Nuts.NO3uM, Nuts.NH3uM, Chl.ChlorA, Chl.Phaeop, Bottle.RecInd INTO BottleData_202107
FROM Cast INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
GROUP BY Cast.Cst_Cnt, Cast.Cruise, Cast.Order_Occ, Cast.Date, Cast.Time, Cast.St_Line, Cast.Cast_ID, Bottle.Sta_ID, Cast.Sta_Code, Cast.Lat_Dec, Cast.Lon_Dec, Cast.Distance, Bottle.Btl_Cnt, Bottle.BtlNum, Bottle.Depthm, Bottle.T_degC, Bottle.Salnty, Bottle.STheta, Bottle.O2ml_L, Bottle.O2Sat, Nuts.PO4uM, Nuts.SiO3uM, Nuts.NO3uM, Nuts.NH3uM, Chl.ChlorA, Chl.Phaeop, Bottle.RecInd
HAVING (((Cast.Cst_Cnt) Between 35645 And 35715))
ORDER BY Cast.Cruise, Bottle.Sta_ID, Bottle.Depthm;
