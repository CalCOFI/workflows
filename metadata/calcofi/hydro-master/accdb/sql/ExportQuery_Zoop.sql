-- query: ExportQuery_Zoop
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Zooplankton.ID, Zooplankton.Cruise, Zooplankton.CruiseAlias, Zooplankton.Sta_ID, Zooplankton.Cruz_Sta, Zooplankton.Ship_Code, Zooplankton.Order_Occ, Zooplankton.Cruz_Code, Zooplankton.St_Line, Zooplankton.St_Station, Zooplankton.Lat_Deg, Zooplankton.Lat_Min, Zooplankton.Lat_Hem, Zooplankton.Lon_Deg, Zooplankton.Lon_Min, Zooplankton.Lon_Hem, Zooplankton.Tow_Type, Zooplankton.Net_Loc, Format([Zooplankton].[End_Time],"Short Time") AS End_Time, Format([Zooplankton].[Tow_Date],"mm/dd/yyyy") AS Tow_Date, Format([Zooplankton].[Tow_Time],"Short Time") AS Tow_Time, Zooplankton.Vol_StrM3, Zooplankton.Tow_DpthM, Zooplankton.Ttl_PVolC3, Zooplankton.Sml_PVolC3, Zooplankton.HaulFact, Zooplankton.Ttl_Eggs_Raw, Zooplankton.Ttl_Larvae_Raw, Zooplankton.Ttl_Eggs_Stnd, Zooplankton.Ttl_Larvae_Stnd, Zooplankton.Sardine_Eggs_Raw, Zooplankton.Sardine_Eggs_Stnd, Zooplankton.Anchovy_Eggs_Raw, Zooplankton.Anchovy_Eggs_Stnd, Zooplankton.Sardine_Larvae_Raw, Zooplankton.Sardine_Larvae_Stnd, Zooplankton.Anchovy_Larvae_Raw, Zooplankton.Anchovy_Larvae_Stnd
FROM Zooplankton
WHERE (((Zooplankton.Cruise)<201804))
ORDER BY Zooplankton.ID;
