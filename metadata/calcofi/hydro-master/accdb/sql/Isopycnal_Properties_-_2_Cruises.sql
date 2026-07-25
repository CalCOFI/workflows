-- query: Isopycnal Properties - 2 Cruises
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Isopycnal Properties - 1 Station].Year, Avg([Isopycnal Properties - 1 Station].YearValue) AS AvgOfYearValue, [Isopycnal Properties - 1 Station].Cruise, Avg([Isopycnal Properties - 1 Station].Date) AS Date, Avg([Isopycnal Properties - 1 Station].Month) AS Month, Sum([Isopycnal Properties - 1 Station].StCount) AS NoStations, Avg([Isopycnal Properties - 1 Station].STheta) AS STheta, Avg([Isopycnal Properties - 1 Station].Depth) AS Depth, Avg([Isopycnal Properties - 1 Station].Temp) AS Temp, Avg([Isopycnal Properties - 1 Station].Sal) AS Sal, Avg([Isopycnal Properties - 1 Station].PO4) AS PO4, Avg([Isopycnal Properties - 1 Station].SiO4) AS SiO4, Avg([Isopycnal Properties - 1 Station].NO2) AS NO2, Avg([Isopycnal Properties - 1 Station].NO3) AS NO3, Avg([Isopycnal Properties - 1 Station].O2) AS O2, Avg([Isopycnal Properties - 1 Station].O2Sat) AS O2Sat, Avg([Isopycnal Properties - 1 Station].[N-P_Ratio]) AS [N-P_Ratio], Avg([Isopycnal Properties - 1 Station].[N-Star]) AS [N-Star]
FROM [Isopycnal Properties - 1 Station]
GROUP BY [Isopycnal Properties - 1 Station].Year, [Isopycnal Properties - 1 Station].Cruise;
