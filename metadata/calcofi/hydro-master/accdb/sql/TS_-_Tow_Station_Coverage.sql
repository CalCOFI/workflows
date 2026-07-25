-- query: TS - Tow Station Coverage
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Avg([TR - NMFS_Tows].NMFS_TowDateTimeGMT) AS AvgOfNMFS_TowDateTimeGMT
SELECT [TR - NMFS_Tows].CC_CruiseNo
FROM NMFS_Station_ID INNER JOIN [TR - NMFS_Tows] ON NMFS_Station_ID.NMFS_Sta_ID = [TR - NMFS_Tows].NMFS_Sta_ID
WHERE (((NMFS_Station_ID.St_Code)="st"))
GROUP BY [TR - NMFS_Tows].CC_CruiseNo
ORDER BY [TR - NMFS_Tows].CC_CruiseNo
PIVOT [TR - NMFS_Tows].St_ID;
