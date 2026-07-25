-- query: QC-DIC_DepthComp
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT DICs.Cruise, Abs([StaPr]-[Depthm]) AS depth_Comp, DICs.Depth_ID, DICs.Depthm, DICs.StaPr, DICs.Btl_Cnt
FROM DICs
WHERE (((DICs.Cruise)=201501));
