-- query: QC-DIC_DepthIDComp
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Abs(Mid([DICs].[Depth_ID],33,3))-Abs(Mid([Bottle].[Depth_ID],33,3)) AS Depth_ID_Compare
FROM DICs INNER JOIN Bottle ON DICs.Btl_Cnt = Bottle.Btl_Cnt;
