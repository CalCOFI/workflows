-- query: ML Data 1 Stations
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Cast.Sta_ID, Avg(Cast.Date) AS Date, Avg(Cast!Month+Day(Cast!Date)/31.5-1) AS Month, Count(Cast.Date) AS SampleCount, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Bottle.STheta) AS Density, Avg(Chl.ChlorA) AS Chl, Avg(Cast.IntChl) AS IntChl, Avg(Cast.IntC14) AS IntC14, Avg(Nuts.PO4uM) AS PO4, Avg(Nuts.SiO3uM) AS SiO4, Avg(Nuts.NO2uM) AS NO2, Avg(Nuts.NO3uM) AS NO3, Avg(MLD_Sigma.MLD_Sigma) AS MLD_Sigma, Avg(NutClineDepth.NCDepth) AS NCDepth, Avg(Bottle.O2Sat) AS O2Sat, Cast.Sta_Code, Avg(Bottle.O2ml_L) AS O2
FROM Cruises INNER JOIN ((St_Stations INNER JOIN ((Cast LEFT JOIN MLD_Sigma ON Cast.Cast_ID = MLD_Sigma.Cast_ID) LEFT JOIN NutClineDepth ON Cast.Cast_ID = NutClineDepth.Cast_ID) ON St_Stations.Sta_ID = Cast.Sta_ID) INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cruises.[Code-ST])="st") And ((Bottle.Depthm)<MLD_Sigma!MLD_Sigma) And ((Bottle.RecInd)=3 Or (Bottle.RecInd)=5))
GROUP BY Cast.Year, Cast.Cruise, Cast.Sta_ID, Cast.Sta_Code
HAVING (((Cast.Cruise)>201611) AND ((Cast.Sta_Code)="st"))
ORDER BY Cast.Cruise;
