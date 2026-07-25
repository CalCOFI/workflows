-- query: Data for Matlab NC Calc
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Cast.Cast_ID, Cast.Sta_ID, Avg(Cast!Date+Cast!Time) AS DateTime, Bottle.Depthm AS Depth, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.STheta) AS STheta, Avg(Nuts.PO4uM) AS PO4, Avg(Nuts.SiO3uM) AS SiO4, Avg(Nuts.NO3uM) AS NO3
FROM Cast INNER JOIN (Bottle LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Bottle.RecInd)=3))
GROUP BY Cast.Year, Cast.Cruise, Cast.Cast_ID, Cast.Sta_ID, Bottle.Depthm
HAVING (((Cast.Cruise)>201611) AND ((Bottle.Depthm)<260) AND ((Avg(Bottle.T_degC))>5) AND ((Avg(Nuts.NO3uM)) Is Not Null))
ORDER BY Cast.Cast_ID, Bottle.Depthm;
