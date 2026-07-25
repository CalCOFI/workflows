-- query: TM - NMFS_Station_ID
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [TR - NMFS_Tows].NMFS_Sta_ID, Count([TR - NMFS_Tows].NMFS_OrdOcc) AS Times_Occup, Avg([TR - NMFS_Tows].NMFS_TowDateTimeGMT) AS NMFS_Time, Avg([TR - NMFS_Tows].NMFS_DLat) AS NMFS_DLat, Avg([TR - NMFS_Tows].NMFS_Dlong) AS NMFS_Dlong INTO [New-NMFS_Station_ID]
FROM [TR - NMFS_Tows]
GROUP BY [TR - NMFS_Tows].NMFS_Sta_ID;
