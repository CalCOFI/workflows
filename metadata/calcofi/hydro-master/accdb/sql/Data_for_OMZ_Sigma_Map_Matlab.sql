-- query: Data for OMZ Sigma Map Matlab
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Cast.Cast_ID, Cast.Sta_ID, Avg(Cast!Date+Cast!Time) AS DateTime, Avg(Bottle.Depthm) AS Depth, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Bottle.O2ml_L) AS O2, Avg(Bottle.O2Sat) AS O2Sat, Bottle.STheta AS STheta, Avg(Nuts.PO4ug) AS PO4, Avg(Nuts.SiO3ug) AS SiO4, Avg(Nuts.NO3ug) AS NO3, Avg(Nuts.NO2ug) AS NO2
FROM Cruises RIGHT JOIN ((St_Stations INNER JOIN Cast ON St_Stations.Sta_ID = Cast.Sta_ID) INNER JOIN (Bottle LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Bottle.RecInd)=3 Or (Bottle.RecInd)=5) AND ((St_Stations.[Code-Nearshore])="near" Or (St_Stations.[Code-Nearshore])="cow"))
GROUP BY Cast.Year, Cast.Cruise, Cast.Cast_ID, Cast.Sta_ID, Bottle.STheta
HAVING (((Avg(Bottle.T_degC))>5) AND ((Avg(Bottle.O2ml_L)) Is Not Null) AND ((Bottle.STheta) Is Not Null))
ORDER BY Cast.Year, Cast.Cruise, Cast.Cast_ID, Cast.Sta_ID, Bottle.STheta;
