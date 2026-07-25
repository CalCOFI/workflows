-- query: TQ - Property Tests_AllDiscreet per depth
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Cast.Sta_ID, Bottle.Depthm AS Depth, Count(Bottle.Depthm) AS DepthCount, Avg(Bottle.STheta) AS STheta, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Nuts.[NO3uM]) AS Nitrate, Avg(Nuts.[PO4uM]) AS Phosphate, Avg(Nuts.[SiO3uM]) AS Silicate, Avg(Bottle.O2Sat) AS O2Sat, [Nitrate]/[Phosphate] AS [N-P Ratio], [Nitrate]/[Silicate] AS [N-Si Ratio], [Phosphate]/[Silicate] AS [P-Si Ratio], [Sal]/[O2Sat] AS [Sal-O2 Ratio], Bottle.RecInd, Bottle.Depth_ID, Bottle.Depth_ID, Cast.Lon_Dec
FROM Cruises INNER JOIN ((Station_ID INNER JOIN Cast ON Station_ID.DBSta_ID = Cast.DbSta_ID) INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) INNER JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cruises.[Code-ST])="st") AND ((Station_ID.St_Line) Between 80 And 90) AND ((Station_ID.St_Sta) Between 50 And 120) AND ((Bottle.Depthm) Between 500 And 550))
GROUP BY Cast.Year, Cast.Cruise, Cast.Sta_ID, Bottle.Depthm, Bottle.RecInd, Bottle.Depth_ID, Cast.Lon_Dec, Station_ID.Sta_Code, Bottle.Depth_ID
HAVING (((Cast.Cruise)>200911) AND ((Bottle.RecInd)=3) AND ((Station_ID.Sta_Code)="st"));
