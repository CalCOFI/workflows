-- query: TQ_DeepValues: PropertyCluster
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Avg([TQ - Property Tests_AllDiscreet per depth].Nitrate) AS AvgOfNitrate
SELECT [TQ - Property Tests_AllDiscreet per depth].Sta_ID, [TQ - Property Tests_AllDiscreet per depth].Depth, [TQ - Property Tests_AllDiscreet per depth].Temp
FROM [TQ - Property Tests_AllDiscreet per depth]
GROUP BY [TQ - Property Tests_AllDiscreet per depth].Sta_ID, [TQ - Property Tests_AllDiscreet per depth].Depth, [TQ - Property Tests_AllDiscreet per depth].Temp
PIVOT [TQ - Property Tests_AllDiscreet per depth].Cruise;
