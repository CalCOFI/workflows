-- query: TI - Zooplankton
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Zooplankton.ID, Zooplankton.Cruise, Zooplankton.Sta_ID, Zooplankton.Cruz_Sta, Zooplankton.Order_Occ, Zooplankton.St_Line, Zooplankton.St_Sta, Avg([Zooplankton]![Lat_Deg]+([Zooplankton]![Lat_Min]/60)) AS Lat_Dec, Avg([Zooplankton]![Lon_Deg]+([Zooplankton]![Lon_Min]/60)) AS Lon_Dec, Zooplankton.Tow_Type, Zooplankton.Net_Loc, Zooplankton.Tow_Date, Zooplankton.Tow_Time, Avg([Zooplankton]![Tow_Date]+[Zooplankton]![Tow_Time]) AS Tow_DateTime, Zooplankton.Tow_DpthM, Zooplankton.Ttl_PVolC3, Zooplankton.Sml_PVolC3
FROM Zooplankton
GROUP BY Zooplankton.ID, Zooplankton.Cruise, Zooplankton.Sta_ID, Zooplankton.Cruz_Sta, Zooplankton.Order_Occ, Zooplankton.St_Line, Zooplankton.St_Sta, Zooplankton.Tow_Type, Zooplankton.Net_Loc, Zooplankton.Tow_Date, Zooplankton.Tow_Time, Zooplankton.Tow_DpthM, Zooplankton.Ttl_PVolC3, Zooplankton.Sml_PVolC3;
