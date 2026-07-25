-- query: ML Data 2 Cruises
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [ML Data 1 Stations].Year, [ML Data 1 Stations].Cruise, Avg([ML Data 1 Stations].Date) AS Date, Avg([ML Data 1 Stations].Month) AS Month, Count([ML Data 1 Stations].SampleCount) AS StationCount, Avg([ML Data 1 Stations].Temp) AS Temp, Avg([ML Data 1 Stations].Sal) AS Sal, Avg([ML Data 1 Stations].Density) AS Density, Avg([ML Data 1 Stations].Chl) AS Chl, Avg([ML Data 1 Stations].IntChl) AS IntChl, Avg([ML Data 1 Stations].IntC14) AS IntC14, Avg([ML Data 1 Stations].PO4) AS PO4, Avg([ML Data 1 Stations].SiO4) AS SiO4, Avg([ML Data 1 Stations].NO2) AS NO2, Avg([ML Data 1 Stations].NO3) AS NO3, Avg([ML Data 1 Stations].MLD_Sigma) AS MLD, Avg([ML Data 1 Stations].NCDepth) AS NCDepth, Avg([ML Data 1 Stations].O2) AS O2, Avg([ML Data 1 Stations].O2Sat) AS O2_Sat
FROM [ML Data 1 Stations]
GROUP BY [ML Data 1 Stations].Year, [ML Data 1 Stations].Cruise;
