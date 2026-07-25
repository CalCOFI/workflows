-- query: TQ - DeepValues_Avg
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Avg(Cast.Date) AS Date, Count(Bottle.Depthm) AS DepthCount, Avg(Bottle.Depthm) AS AvgDepth, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Bottle.STheta) AS Density, Avg(Nuts.PO4uM) AS PO4, Avg(Nuts.SiO3uM) AS SiO4, Avg(Nuts.NO2uM) AS NO2, Avg(Nuts.NO3uM) AS NO3, Avg(Bottle.O2ml_L) AS O2, [NO3]/[PO4] AS [N-P Ratio], [NO3]/[SiO4] AS [N-Si Ratio], [PO4]/[SiO4] AS [P-Si Ratio], [Sal]/[O2] AS [Sal-O2 Ratio], [NO3]/[Sal] AS [N-Sal Ratio], [PO4]/[Sal] AS [P-Sal Ratio], [Sio4]/[Sal] AS [Si-Sal], StDev(Nuts.PO4uM) AS StDevOfPO4ug, StDev(Bottle.Salnty) AS StDevOfSalnty
FROM Cruises INNER JOIN ((Station_ID INNER JOIN Cast ON Station_ID.DBSta_ID = Cast.DbSta_ID) INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Bottle.Depthm) Between 400 And 550) AND ((Bottle.RecInd)=3) AND ((Cruises.[Code-ST])="st") AND ((Station_ID.St_Sta) Between 50 And 120) AND ((Station_ID.St_Line) Between 80 And 90))
GROUP BY Cast.Year, Cast.Cruise, Cast.Year
HAVING (((Cast.Year)>1983));
