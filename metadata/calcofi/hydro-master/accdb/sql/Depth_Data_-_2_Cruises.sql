-- query: Depth Data - 2 Cruises
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Depth Data - 1 Stations].Year, [Depth Data - 1 Stations].Cruise, Avg([Depth Data - 1 Stations].Date) AS Date, Avg([Depth Data - 1 Stations].Month) AS Month, Count([Depth Data - 1 Stations].Depth) AS St_Count, Avg([Depth Data - 1 Stations].Depth) AS Depth, Avg([Depth Data - 1 Stations].Temp) AS Temp, Avg([Depth Data - 1 Stations].Sal) AS Sal, Avg([Depth Data - 1 Stations].Density) AS Density, Avg([Depth Data - 1 Stations].Chl) AS Chl, Avg([Depth Data - 1 Stations].PO4) AS PO4, Avg([Depth Data - 1 Stations].SiO4) AS SiO4, Avg([Depth Data - 1 Stations].NO2) AS NO2, Avg([Depth Data - 1 Stations].NO3) AS NO3, Avg([Depth Data - 1 Stations].O2) AS O2
FROM [Depth Data - 1 Stations]
GROUP BY [Depth Data - 1 Stations].Year, [Depth Data - 1 Stations].Cruise;
