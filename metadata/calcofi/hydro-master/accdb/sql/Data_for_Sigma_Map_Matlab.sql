-- query: Data for Sigma Map Matlab
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Cast.Cast_ID, Cast.Sta_ID, Avg(Cast!Date+Cast!Time) AS DateTime, Avg(Bottle.Depthm) AS Depth, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Bottle.O2ml_L) AS O2, Avg(Bottle.O2Sat) AS O2Sat, Bottle.STheta AS STheta, Avg(Nuts.PO4uM) AS PO4, Avg(Nuts.SiO3uM) AS SiO4, Avg(Nuts.NO3uM) AS NO3, Avg(Nuts.NO2uM) AS NO2
FROM Cruises RIGHT JOIN ((St_Stations INNER JOIN Cast ON St_Stations.Sta_ID = Cast.Sta_ID) INNER JOIN (Bottle LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Bottle.RecInd)=3 Or (Bottle.RecInd)=5))
GROUP BY Cast.Year, Cast.Cruise, Cast.Cast_ID, Cast.Sta_ID, Bottle.STheta
HAVING (((Cast.Cruise)>198400) AND ((Avg(Bottle.T_degC))>5) AND ((Bottle.STheta) Is Not Null))
ORDER BY Cast.Year, Cast.Cruise, Cast.Cast_ID, Cast.Sta_ID, Bottle.STheta;
