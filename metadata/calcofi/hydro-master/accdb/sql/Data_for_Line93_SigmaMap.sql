-- query: Data for Line93 SigmaMap
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Cast.Cast_ID, Cast.Sta_ID, Avg(Cast!Date+Cast!Time) AS DateTime, Bottle.Depthm AS Depth, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Bottle.O2ml_L) AS O2, Avg(Bottle.O2Sat) AS O2Sat, Avg(Bottle.STheta) AS STheta, Avg(Nuts.PO4ug) AS PO4, Avg(Nuts.SiO3ug) AS SiO4, Avg(Nuts.NO3ug) AS NO3, Avg(Nuts.NO2ug) AS AvgOfNO2ug
FROM Cruises RIGHT JOIN ((Cast LEFT JOIN Station_ID ON Cast.Sta_ID = Station_ID.Sta_ID) INNER JOIN (Bottle LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Bottle.RecInd)=3 Or (Bottle.RecInd)=5))
GROUP BY Cast.Year, Cast.Cruise, Cast.Cast_ID, Cast.Sta_ID, Bottle.Depthm
HAVING (((Cast.Cruise)>198400) AND ((Avg(Bottle.STheta)) Is Not Null))
ORDER BY Cast.Year, Cast.Cast_ID, Bottle.Depthm;
