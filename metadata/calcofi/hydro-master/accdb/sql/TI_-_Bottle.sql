-- query: TI - Bottle
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Cast.Date, Cast.Cast_ID, Cast.St_Line, Bottle.Sta_ID, Cast.Sta_Code, Bottle.Depthm, Bottle.T_degC, Bottle.Salnty, Bottle.O2ml_L, Bottle.STheta, Bottle.O2Sat, Nuts.PO4ug, Nuts.SiO3ug, Nuts.NO3ug, Chl.ChlorA, Bottle.RecInd
FROM Cast INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
GROUP BY Cast.Cruise, Cast.Date, Cast.Cast_ID, Cast.St_Line, Bottle.Sta_ID, Cast.Sta_Code, Bottle.Depthm, Bottle.T_degC, Bottle.Salnty, Bottle.O2ml_L, Bottle.STheta, Bottle.O2Sat, Nuts.PO4ug, Nuts.SiO3ug, Nuts.NO3ug, Chl.ChlorA, Bottle.RecInd
HAVING (((Cast.Cast_ID)="20-1004FN-PR-119-1742-09331100"))
ORDER BY Bottle.Sta_ID;
