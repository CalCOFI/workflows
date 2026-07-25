-- query: Anomalies Sigma 1 Regions Cruise
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Anomalies Sigma 0 IM].Year, Avg([Anomalies Sigma 0 IM].YearValue) AS YearValue, [Anomalies Sigma 0 IM].Sigma AS Sigma, [Anomalies Sigma 0 IM].Cruise, Avg([Anomalies Sigma 0 IM].Date) AS Date, Month([Date])+Day([Date])/30 AS Month, Count([Anomalies Sigma 0 IM].Depth) AS NoStations, Avg([Anomalies Sigma 0 IM].Depth) AS Depth, Avg([Anomalies Sigma 0 IM].Temp) AS Temp, Avg([Anomalies Sigma 0 IM].Sal) AS Sal, Avg([Anomalies Sigma 0 IM].O2) AS O2, Avg([Anomalies Sigma 0 IM].O2Sat) AS O2Sat, Avg([Anomalies Sigma 0 IM].PO4) AS PO4, Avg([Anomalies Sigma 0 IM].SiO4) AS SiO4, Avg([Anomalies Sigma 0 IM].NO3) AS NO3, Avg([Anomalies Sigma 0 IM].DepthAnom) AS DepthAnom, Avg([Anomalies Sigma 0 IM].TempAnom) AS TempAnom, Avg([Anomalies Sigma 0 IM].SalAnom) AS SalAnom, Avg([Anomalies Sigma 0 IM].O2Anom) AS O2Anom, Avg([Anomalies Sigma 0 IM].NO3Anom) AS NO3Anom, Avg([Anomalies Sigma 0 IM].PO4Anom) AS PO4Anom, Avg([Anomalies Sigma 0 IM].SiO3Anom) AS SiO3Anom, Avg([Anomalies Sigma 0 IM].[N-P_Ratio]) AS [N-P_Ratio], Avg([Anomalies Sigma 0 IM].[N-Star]) AS [N-Star]
FROM St_Stations INNER JOIN (Cruises INNER JOIN (Cast INNER JOIN [Anomalies Sigma 0 IM] ON Cast.Cast_ID = [Anomalies Sigma 0 IM].Cast_ID) ON Cruises.Cruise = [Anomalies Sigma 0 IM].Cruise) ON (Cruises.Cruise = Cast.Cruise) AND (St_Stations.Sta_ID = Cast.Sta_ID)
WHERE (((Cruises.[Code-ST])="ST"))
GROUP BY [Anomalies Sigma 0 IM].Year, [Anomalies Sigma 0 IM].Sigma, [Anomalies Sigma 0 IM].Cruise
HAVING ((([Anomalies Sigma 0 IM].Sigma)=26.6));
