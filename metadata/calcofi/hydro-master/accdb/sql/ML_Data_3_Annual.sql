-- query: ML Data 3 Annual
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [ML Data 2 Cruises].Year, Avg([ML Data 2 Cruises].Date) AS Date, Avg([ML Data 2 Cruises].Month) AS Month, Count([ML Data 2 Cruises].StationCount) AS CruiseCount, Avg([ML Data 2 Cruises].Temp) AS Temp, Avg([ML Data 2 Cruises].Sal) AS Sal, Avg([ML Data 2 Cruises].Density) AS Density, Avg([ML Data 2 Cruises].Chl) AS Chl, Avg([ML Data 2 Cruises].IntChl) AS IntChl, Avg([ML Data 2 Cruises].IntC14) AS IntC14, Avg([ML Data 2 Cruises].PO4) AS PO4, Avg([ML Data 2 Cruises].SiO4) AS SiO4, Avg([ML Data 2 Cruises].NO2) AS NO2, Avg([ML Data 2 Cruises].NO3) AS NO3, Avg([ML Data 2 Cruises].MLD) AS MLD, Avg([ML Data 2 Cruises].NCDepth) AS NCDepth, Avg([ML Data 2 Cruises].O2) AS O2, Avg([ML Data 2 Cruises].O2_Sat) AS O2_Sat
FROM [ML Data 2 Cruises]
GROUP BY [ML Data 2 Cruises].Year;
