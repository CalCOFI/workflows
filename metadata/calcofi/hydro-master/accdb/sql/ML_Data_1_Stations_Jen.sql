-- query: ML Data 1 Stations_Jen
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Cast.Sta_ID, St_Stations.St_Line, St_Stations.[Code-SCB] AS Code_SCB, St_Stations.[Code-Nearshore] AS Code_Nearshore, St_Stations.Code_Region, St_Stations.St_Station AS St_Sta, St_Stations.Distance, St_Stations.DLat_Dec, St_Stations.DLon_Dec, Avg(Cast.Date) AS Date, Cast.Quarter, Year([Date])+Month([Date])/12 AS YearValue, Avg([Cast]![Month]+Day([Cast]![Date])/31.5-1) AS MonthValue, Count(Cast.Date) AS SampleCount, (4-5) AS Depth, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Bottle.STheta) AS Density, Avg(Bottle.O2ml_L) AS O2, Avg(Bottle.O2Sat) AS O2Sat, Avg(Chl.ChlorA) AS Chla, Avg(Nuts.NO3uM) AS NO3, Avg(Nuts.NO2uM) AS NO2, Avg(Nuts.PO4uM) AS PO4, Avg(Nuts.SiO3uM) AS SiO3, Avg(Cast.IntChl) AS IntChl, Avg(Cast.IntC14) AS IntC14, Avg(MLD_Sigma.MLD_Sigma) AS MLD_Sigma, Avg(NutClineDepth.NCDepth) AS NCDepth, Cast.Sta_Code
FROM Cruises INNER JOIN ((St_Stations INNER JOIN ((Cast LEFT JOIN MLD_Sigma ON Cast.Cast_ID = MLD_Sigma.Cast_ID) LEFT JOIN NutClineDepth ON Cast.Cast_ID = NutClineDepth.Cast_ID) ON St_Stations.Sta_ID = Cast.Sta_ID) INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cruises.[Code-ST])="st") AND ((Bottle.Depthm)<[MLD_Sigma]![MLD_Sigma]) AND ((Bottle.RecInd)=3 Or (Bottle.RecInd)=5))
GROUP BY Cast.Year, Cast.Cruise, Cast.Sta_ID, St_Stations.St_Line, St_Stations.[Code-SCB], St_Stations.[Code-Nearshore], St_Stations.Code_Region, St_Stations.St_Station, St_Stations.Distance, St_Stations.DLat_Dec, St_Stations.DLon_Dec, Cast.Quarter, Cast.Sta_Code
HAVING (((Cast.Cruise)=201511) AND ((Cast.Sta_Code)="st"))
ORDER BY Cast.Cruise;
