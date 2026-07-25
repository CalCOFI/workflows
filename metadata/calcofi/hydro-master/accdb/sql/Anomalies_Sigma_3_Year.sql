-- query: Anomalies Sigma 3 Year
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Anomalies Sigma 2 Cruises].Year AS Expr1, Avg([Anomalies Sigma 2 Cruises].Date) AS Date, Avg([Anomalies Sigma 2 Cruises].Month) AS Month, Count([Anomalies Sigma 2 Cruises].Cruise) AS NoCruises, Avg([Anomalies Sigma 2 Cruises].Sigma) AS Sigma, Avg([Anomalies Sigma 2 Cruises].Depth) AS Depth, Avg([Anomalies Sigma 2 Cruises].Temp) AS Temp, Avg([Anomalies Sigma 2 Cruises].Sal) AS Sal, Avg([Anomalies Sigma 2 Cruises].PO4) AS PO4, Avg([Anomalies Sigma 2 Cruises].SiO4) AS SiO4, Avg([Anomalies Sigma 2 Cruises].NO3) AS NO3, Avg([Anomalies Sigma 2 Cruises].O2) AS O2, Avg([Anomalies Sigma 2 Cruises].DepthAnom) AS DepthAnom, Avg([Anomalies Sigma 2 Cruises].TempAnom) AS TempAnom, Avg([Anomalies Sigma 2 Cruises].SalAnom) AS SalAnom, Avg([Anomalies Sigma 2 Cruises].PO4Anom) AS PO4Anom, Avg([Anomalies Sigma 2 Cruises].SiO3Anom) AS SiO3Anom, Avg([Anomalies Sigma 2 Cruises].NO3Anom) AS NO3Anom, Avg([Anomalies Sigma 2 Cruises].O2Anom) AS O2Anom
FROM [Anomalies Sigma 2 Cruises]
GROUP BY [Anomalies Sigma 2 Cruises].Year
ORDER BY [Anomalies Sigma 2 Cruises].Year, Avg([Anomalies Sigma 2 Cruises].Sigma);
