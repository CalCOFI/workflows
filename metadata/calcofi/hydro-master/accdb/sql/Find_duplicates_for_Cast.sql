-- query: Find duplicates for Cast
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.[Date], Cast.[Sta_ID], Cast.[Cruise]
FROM Cast
WHERE (((Cast.[Date]) In (SELECT [Date] FROM [Cast] As Tmp GROUP BY [Date],[Sta_ID] HAVING Count(*)>1  And [Sta_ID] = [Cast].[Sta_ID])))
ORDER BY Cast.[Date], Cast.[Sta_ID];
