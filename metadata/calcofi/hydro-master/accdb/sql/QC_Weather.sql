-- query: QC_Weather
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Cast.Sta_ID, Weather.Wave_Dir, Weather.Wave_Ht, Weather.Wave_Prd, Weather.Wind_Dir, Weather.Wind_Spd, Weather.Barometer, Weather.Dry_T, Weather.Wet_T, Weather.Wea, Weather.Cloud_Typ, Weather.Cloud_Amt, Weather.Visibility, Weather.Secchi, Cast.Order_Occ
FROM Cast INNER JOIN Weather ON Cast.Cst_Cnt = Weather.Cst_Cnt
WHERE (((Cast.Cruise)=201207));
