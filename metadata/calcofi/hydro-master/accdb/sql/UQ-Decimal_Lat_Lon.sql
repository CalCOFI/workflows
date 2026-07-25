-- query: UQ-Decimal Lat/Lon
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast
SET Cast.Lat_Dec = Cast.Lat_Deg+(Cast.Lat_Min/60), Cast.Lon_Dec = Cast.Lon_Deg-(Cast.Lon_Min/60);
