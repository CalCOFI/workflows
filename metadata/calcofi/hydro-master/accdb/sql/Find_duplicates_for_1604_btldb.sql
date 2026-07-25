-- query: Find duplicates for 1604_btldb
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT First([1604_btldb].[Btl_Cnt]) AS [Btl_Cnt Field], First([1604_btldb].[Depth_ID]) AS [Depth_ID Field], Count([1604_btldb].[Btl_Cnt]) AS NumberOfDups
FROM 1604_btldb
GROUP BY [1604_btldb].[Btl_Cnt], [1604_btldb].[Depth_ID]
HAVING (((Count([1604_btldb].[Btl_Cnt]))>1) AND ((Count([1604_btldb].[Depth_ID]))>1));
