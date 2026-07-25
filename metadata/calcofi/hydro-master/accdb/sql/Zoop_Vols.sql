-- query: Zoop_Vols
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Zooplankton.Cruise, Zooplankton.Sta_ID, Zooplankton.Cruz_Sta, Zooplankton.Ship_Code, Zooplankton.Order_Occ, Zooplankton.St_Line, Zooplankton.St_Station, Zooplankton.Lat_Deg, Zooplankton.Lat_Min, Zooplankton.Lat_Hem, Zooplankton.Lon_Deg, Zooplankton.Lon_Min, Zooplankton.Lon_Hem, Zooplankton.Tow_Type, Zooplankton.Net_Loc, Zooplankton.Tow_Date, Zooplankton.Tow_Time, Zooplankton.End_Time, Zooplankton.Vol_StrM3, Zooplankton.Tow_DpthM, Zooplankton.Ttl_PVolC3, Zooplankton.Sml_PVolC3, Zooplankton.HaulFact
FROM Zooplankton
WHERE (((Zooplankton.Cruise)=201704) AND ((Zooplankton.Net_Loc)="S"));
