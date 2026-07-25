-- query: Mati_Meta_Query
-- type:  MAKE_TABLE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cst_Cnt, Cast.Cruise_ID, Cast.Cruise, Cast.CruiseAlias, Cast.Cruz_Sta, Cast.DbSta_ID, Cast.Cast_ID, Cast.Sta_ID, Cast.Quarter, Cast.Sta_Code, Cast.Distance, Format([Cast].[Date],"mm/dd/yyyy") AS Date, Cast.Year, Cast.Month, Cast.Julian_Date, Cast.Julian_Day, Format([Cast].[Time],"hh:nn:ss") AS Time, Cast.Lat_Dec, Cast.Lat_Deg, Cast.Lat_Min, Cast.Lat_Hem, Cast.Lon_Dec, Cast.Lon_Deg, Cast.Lon_Min, Cast.Lon_Hem, Cast.Rpt_Line, Cast.St_Line, Cast.Ac_Line, Cast.Rpt_Sta, Cast.St_Station, Cast.Ac_Sta, Cast.Bottom_D, Cast.Secchi, Cast.ForelU, Cast.Ship_Name, Cast.Ship_Code, Cast.Data_Type, Cast.Order_Occ, Cast.Event_Num, Cast.Cruz_Leg, Cast.Orig_Sta_ID, Cast.Data_Or, Cast.Cruz_Num, Cast.IntChl, Cast.IntC14 INTO [Mati_Meta_201902-202101]
FROM Cast
WHERE (((Cast.Cruise) Between 202204 And 202208));
