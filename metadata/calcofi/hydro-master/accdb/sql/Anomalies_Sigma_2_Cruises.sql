-- query: Anomalies Sigma 2 Cruises
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Anomalies Sigma 1 Lines].Year AS Expr1, Avg([Anomalies Sigma 1 Lines].YearValue) AS YearValue, Avg([Anomalies Sigma 1 Lines].Sigma) AS Sigma, [Anomalies Sigma 1 Lines].Cruise AS Expr2, Avg([Anomalies Sigma 1 Lines].Date) AS Date, Month([Date]) AS Month, Count([Anomalies Sigma 1 Lines].NoStations) AS NoStations, Avg([Anomalies Sigma 1 Lines].Depth) AS Depth, Avg([Anomalies Sigma 1 Lines].Temp) AS Temp, Avg([Anomalies Sigma 1 Lines].Sal) AS Sal, Avg([Anomalies Sigma 1 Lines].PO4) AS PO4, Avg([Anomalies Sigma 1 Lines].SiO4) AS SiO4, Avg([Anomalies Sigma 1 Lines].NO3) AS NO3, Avg([Anomalies Sigma 1 Lines].O2) AS O2, Avg([Anomalies Sigma 1 Lines].DepthAnom) AS DepthAnom, Avg([Anomalies Sigma 1 Lines].TempAnom) AS TempAnom, Avg([Anomalies Sigma 1 Lines].SalAnom) AS SalAnom, Avg([Anomalies Sigma 1 Lines].PO4Anom) AS PO4Anom, Avg([Anomalies Sigma 1 Lines].SiO3Anom) AS SiO3Anom, Avg([Anomalies Sigma 1 Lines].NO3Anom) AS NO3Anom, Avg([Anomalies Sigma 1 Lines].O2Anom) AS O2Anom
FROM [Anomalies Sigma 1 Lines]
GROUP BY [Anomalies Sigma 1 Lines].Year, [Anomalies Sigma 1 Lines].Cruise
ORDER BY Avg([Anomalies Sigma 1 Lines].Sigma), [Anomalies Sigma 1 Lines].Cruise;
