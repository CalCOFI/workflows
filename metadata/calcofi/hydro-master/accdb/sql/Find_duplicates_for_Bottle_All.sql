-- query: Find duplicates for Bottle_All
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT First(Bottle_All.[Btl_Cnt]) AS [Btl_Cnt Field], Count(Bottle_All.[Btl_Cnt]) AS NumberOfDups
FROM Bottle_All
GROUP BY Bottle_All.[Btl_Cnt]
HAVING (((Count(Bottle_All.[Btl_Cnt]))>1));
