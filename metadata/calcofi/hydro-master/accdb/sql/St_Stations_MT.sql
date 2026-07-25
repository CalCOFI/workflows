-- query: St_Stations MT
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Station_ID.St_Line, Station_ID.Sta_ID, Station_ID.DLat_Dec, Station_ID.DLon_Dec, -Station_ID!Distance AS Distance INTO [St_Stations New]
FROM Station_ID
WHERE (((Station_ID.Sta_Code)="st"))
GROUP BY Station_ID.St_Line, Station_ID.Sta_ID, Station_ID.DLat_Dec, Station_ID.DLon_Dec, -Station_ID!Distance;
