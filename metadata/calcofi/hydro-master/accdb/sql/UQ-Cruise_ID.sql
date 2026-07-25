-- query: UQ-Cruise_ID
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cruises INNER JOIN Cast ON Cruises.Cruise = Cast.Cruise
SET Cast.Cruise_ID = UCase(Format(cruises.begdate1,"yyyy-mm-dd"))+"-C-"+cast.ship_code;
