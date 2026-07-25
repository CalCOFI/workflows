-- query: Find duplicates for 1504NH Volumesdb
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [1504NH Volumesdb].[ID], [1504NH Volumesdb].[Cruise], [1504NH Volumesdb].[Sta_ID]
FROM [1504NH Volumesdb]
WHERE ((([1504NH Volumesdb].[ID]) In (SELECT [ID] FROM [1504NH Volumesdb] As Tmp GROUP BY [ID] HAVING Count(*)>1 )))
ORDER BY [1504NH Volumesdb].[ID];
