-- query: Isopycnal Properties - 3 Annual
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Isopycnal Properties - 2 Cruises].Year, Avg([Isopycnal Properties - 2 Cruises].Date) AS AvgDate, Avg([Isopycnal Properties - 2 Cruises].Month) AS AvgMonth, Count([Isopycnal Properties - 2 Cruises].NoStations) AS CruiseCount, Avg([Isopycnal Properties - 2 Cruises].STheta) AS STheta, Avg([Isopycnal Properties - 2 Cruises].Depth) AS Depth, Avg([Isopycnal Properties - 2 Cruises].Temp) AS Temp, Avg([Isopycnal Properties - 2 Cruises].Sal) AS Sal, Avg([Isopycnal Properties - 2 Cruises].PO4) AS PO4, Avg([Isopycnal Properties - 2 Cruises].SiO4) AS SiO4, Avg([Isopycnal Properties - 2 Cruises].NO2) AS NO2, Avg([Isopycnal Properties - 2 Cruises].NO3) AS NO3, Avg([Isopycnal Properties - 2 Cruises].O2) AS O2, Avg([Isopycnal Properties - 2 Cruises].O2Sat) AS O2Sat
FROM [Isopycnal Properties - 2 Cruises]
GROUP BY [Isopycnal Properties - 2 Cruises].Year;
