-- query: Anomalies Sigma for Cruise Maps
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Anomalies Sigma 0 IM].Sigma AS Sigma, Avg(Cast.Year) AS AvgOfYear, St_Stations.Sta_ID, Avg(St_Stations.DLat_Dec) AS Lat, Avg(St_Stations.DLon_Dec) AS Long, Avg([Anomalies Sigma 0 IM].Depth) AS Depth, Avg([Anomalies Sigma 0 IM].Temp) AS Temp, Avg([Anomalies Sigma 0 IM].Sal) AS Sal, Avg([Anomalies Sigma 0 IM].PO4) AS PO4, Avg([Anomalies Sigma 0 IM].SiO4) AS SiO4, Avg([Anomalies Sigma 0 IM].NO3) AS NO3, Avg([Anomalies Sigma 0 IM].O2) AS O2, Avg([Anomalies Sigma 0 IM].DepthAnom) AS DepthAnom, Avg([Anomalies Sigma 0 IM].TempAnom) AS TempAnom, Avg([Anomalies Sigma 0 IM].SalAnom) AS SalAnom, Avg([Anomalies Sigma 0 IM].PO4Anom) AS PO4Anom, Avg([Anomalies Sigma 0 IM].SiO3Anom) AS SiO3Anom, Avg([Anomalies Sigma 0 IM].NO3Anom) AS NO3Anom, Avg([Anomalies Sigma 0 IM].O2Anom) AS O2Anom, Avg([Anomalies Sigma 0 IM]!DepthAnom/[Anomalies Sigma 0 IM]!DepthStDev) AS DepthStAnom, Avg([Anomalies Sigma 0 IM]!TempAnom/[Anomalies Sigma 0 IM]!TempStDev) AS TempStAnom, Avg([Anomalies Sigma 0 IM]!SalAnom/[Anomalies Sigma 0 IM]!SalStDev) AS SalStAnom, Avg([Anomalies Sigma 0 IM]!NO3Anom/[Anomalies Sigma 0 IM]!NO3StDev) AS NO3StAnom, Avg([Anomalies Sigma 0 IM]!O2Anom/[Anomalies Sigma 0 IM]!O2StDev) AS O2StAnom
FROM St_Stations INNER JOIN ((Cruises INNER JOIN Cast ON Cruises.Cruise = Cast.Cruise) INNER JOIN [Anomalies Sigma 0 IM] ON (Cast.Cast_ID = [Anomalies Sigma 0 IM].Cast_ID) AND (Cast.Cruise = [Anomalies Sigma 0 IM].Cruise)) ON St_Stations.Sta_ID = Cast.Sta_ID
WHERE (((Cast.Cruise) Between 201100 And 201412))
GROUP BY [Anomalies Sigma 0 IM].Sigma, St_Stations.Sta_ID
HAVING ((([Anomalies Sigma 0 IM].Sigma)=26.4));
