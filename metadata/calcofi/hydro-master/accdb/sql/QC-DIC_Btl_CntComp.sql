-- query: QC-DIC_Btl_CntComp
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Bottle.Btl_Cnt, Bottle.Depth_ID, DICs.Btl_Cnt, DICs.Depth_ID, DICs.Cruise, Abs(Mid([Bottle]![Depth_ID],32,4)-Mid([DICs]![Depth_ID],32,4)) AS DepthID_Compare, [DICs]![StaPr]-Abs(Mid([Bottle].[Depth_ID],32,4)) AS [DIC_StaPr-Btl_DepthID_Depth], [DICs]![StaPr]-[Bottle]![Depthm] AS [DIC_StaPres-Btl_Depthm], [DICs]![Salinity1]-[Bottle]![Salnty] AS SalComp, DICs.Salinity1, Bottle.Salnty, DICs.TA1, DICs.Comments
FROM Bottle INNER JOIN DICs ON Bottle.Btl_Cnt = DICs.Btl_Cnt
WHERE (((DICs.Cruise)=201407));
