-- query: Depth Data - 3 Annual
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Depth Data - 2 Cruises].Year, Avg([Depth Data - 2 Cruises].Depth) AS Depth, Avg([Depth Data - 2 Cruises].Temp) AS Temp, Avg([Depth Data - 2 Cruises].Sal) AS Sal, Avg([Depth Data - 2 Cruises].Density) AS Density, Avg([Depth Data - 2 Cruises].Chl) AS Chl, Avg([Depth Data - 2 Cruises].PO4) AS PO4, Avg([Depth Data - 2 Cruises].SiO4) AS SiO4, Avg([Depth Data - 2 Cruises].NO2) AS NO2, Avg([Depth Data - 2 Cruises].NO3) AS NO3, Avg([Depth Data - 2 Cruises].O2) AS O2
FROM [Depth Data - 2 Cruises]
GROUP BY [Depth Data - 2 Cruises].Year;
